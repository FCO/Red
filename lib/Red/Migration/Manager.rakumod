use Red;
use Red::Migration::Configuration;
use Red::Migration::Snapshot;
use Red::Migration::Planner;
use Red::Migration::Applied;
use Red::Migration::SQL;
use X::Red::Migration;
use UUID;
use nqp;

unit class Red::Migration::Manager;

# Delegate pure translation to the driver's type object, without constructing a
# connection. Driver constructors may connect eagerly (notably MySQL).
class Translation {
    has Mu $.backend is required;
    method FALLBACK(Str $method, |args) { $!backend."$method"(|args) }
    method execute(|) { X::Red::Migration.new(:reason('Offline translation cannot execute SQL')).throw }
}

has Red::Migration::Configuration $.config is required;

method !error(Str $reason) { X::Red::Migration.new(:$reason).throw }
method !checksum(Str $source --> Str) { nqp::sha1($source) }
method !execute($db, Str $sql) {
    my $statement = $db.prepare($sql);
    my $executed = False;
    LEAVE {
        if $executed { $statement.finish-transaction }
        elsif $db.driver-name.ends-with(any(<SQLite MySQL>)) { try $statement.statement.finish }
    }
    $statement.execute;
    $executed = True;
}
method !row($db, Str $sql, *@bind) {
    my $statement = $db.execute($sql, |@bind);
    LEAVE $statement.finish-transaction;
    $statement.row
}
method !load(IO() $path) {
    use MONKEY-SEE-NO-EVAL;
    EVALFILE $path.absolute
}
method !driver(Str $name) {
    self!error("Unsupported migration driver: $name") unless $name eq any(<SQLite Pg MySQL>);
    require ::("Red::Driver::$name");
    Translation.new(:backend(::("Red::Driver::$name")))
}
method !connection(Str $name) {
    my $db = $!config.connections{$name};
    $db = $db() if $db ~~ Callable;
    self!error("Unknown configured connection: $name") unless $db ~~ Red::Driver:D;
    $db
}
method !dialect($db --> Str) {
    my $name = $db.driver-name.split('::').tail;
    self!error("Unsupported migration connection: $name") unless $name eq any(<SQLite Pg MySQL>);
    $name
}
method !id(--> Str) {
    my $hex = UUID.new.Str.subst('-', '', :g);
    # Exclude the UUID version and variant nibbles from the random component.
    my $random = ($hex.substr(0, 12) ~ $hex.substr(13, 3) ~ $hex.substr(17, 5)).parse-base(16);
    my $number = (DateTime.now.posix * 1000).Int * 2**80 + $random;
    my $alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
    my $id = '';
    for ^26 { $id = $alphabet.substr($number % 32, 1) ~ $id; $number div= 32 }
    $id
}
method history(--> Array) {
    return [] unless $!config.directory.d;
    my @versions;
    for $!config.directory.dir.grep({ .d && !.basename.starts-with('.') }).sort(*.basename) -> $dir {
        my $file = $dir.add('migration.rakuconf');
        self!error("Missing migration manifest: $file") unless $file.f;
        my %m = self!load($file);
        self!error("Unsupported migration format: $file") unless (%m<format> // 0) == 1;
        self!error("Invalid migration ID: $file") unless (%m<id> // '') ~~ /^ <[0..9A..Z]> ** 26 $/;
        self!error("Duplicate migration ID: {%m<id>}") if @versions.grep(*.<id> eq %m<id>);
        %m<path> = $dir;
        @versions.push: %m;
    }
    # Follow ancestry, not filename order: IDs aid review but do not merge histories.
    my @ordered;
    my $previous = '';
    while @versions {
        my @next = @versions.grep({ (.<predecessor> // '') eq $previous });
        self!error('Divergent or incomplete migration history') unless @next.elems == 1;
        my %m = @next[0];
        @ordered.push: %m;
        $previous = %m<id>;
        @versions = @versions.grep(*.<id> ne $previous);
    }
    @ordered.Array
}
method prepare(Str $name, Bool :$allow-destructive = False) {
    self!error('Migration name must contain letters, digits, underscores or hyphens')
        unless $name ~~ /^ <[A..Za..z0..9_-]>+ $/;
    self!error('Configure at least one model and driver') unless $!config.model-types && $!config.drivers;
    self!error('Duplicate configured drivers') unless $!config.drivers.unique.elems == $!config.drivers.elems;
    $!config.directory.mkdir unless $!config.directory.d;
    my $lock = $!config.directory.add('.prepare.lock').open(:a);
    LEAVE $lock.close if $lock.defined;
    self!error('Another process is preparing a migration') unless $lock.lock(:non-blocking);
    my @history = self.history;
    my $previous = @history ?? @history.tail<id> !! '';
    my %artifacts;
    my %drivers;
    my $changed = False;
    for $!config.drivers.sort -> $dialect {
        self!scripts(@history, $dialect) if @history;
        my $db = self!driver($dialect);
        my $planner = Red::Migration::Planner.new(:driver($db), :$dialect);
        my $new = $planner.capture($!config.model-types);
        my $old = Red::Migration::Snapshot.new;
        if @history {
            my $file = @history.tail<path>.add($dialect).add('schema.rakuconf');
            self!error("Previous migration has no $dialect snapshot") unless $file.f;
            self!error("Modified snapshot: $file")
                unless self!checksum($file.slurp) eq @history.tail<drivers>{$dialect}<snapshot-checksum>;
            $old = Red::Migration::Snapshot.load($file);
        }
        my @up = $planner.diff($old, $new, :$allow-destructive);
        $changed ||= so @up;
        my @down;
        my $reason = '';
        try {
            @down = $planner.diff($new, $old, :allow-destructive);
            CATCH { when X::Red::Migration { $reason = .message } }
        }
        my $source = $new.source;
        %artifacts{$dialect} = %(snapshot => $source,
            up => @up.map(* ~ ';').join("\n\n") ~ "\n",
            down => $reason ?? "-- Automatic rollback unavailable: $reason\n"
                !! @down.map(* ~ ';').join("\n\n") ~ "\n");
        statements(%artifacts{$dialect}<up>, :$dialect);
        statements(%artifacts{$dialect}<down>, :$dialect);
        %drivers{$dialect} = %(reversible => !$reason, down-reason => $reason,
            snapshot-checksum => self!checksum($source));
    }
    return Nil unless $changed;
    my $id = self!id;
    my %manifest = format => 1, :$id, :$name, predecessor => $previous, :%drivers;
    $!config.directory.mkdir unless $!config.directory.d;
    my $staging = $!config.directory.add(".$id-{$*PID}");
    $staging.mkdir;
    # Publish only after all dialects have generated and validated successfully.
    for %artifacts.keys.sort -> $dialect {
        my $dir = $staging.add($dialect); $dir.mkdir;
        $dir.add('schema.rakuconf').spurt: %artifacts{$dialect}<snapshot>;
        $dir.add('up.sql').spurt: %artifacts{$dialect}<up>;
        $dir.add('down.sql').spurt: %artifacts{$dialect}<down>;
    }
    $staging.add('migration.rakuconf').spurt: %manifest.raku ~ "\n";
    my $path = $!config.directory.add("$id-$name");
    my @current = self.history;
    self!error('Migration history changed during preparation; retry')
        unless (@current ?? @current.tail<id> !! '') eq $previous;
    $staging.rename($path);
    $path
}
method !scripts(@history, Str $dialect --> Array) {
    @history.map(-> %m {
        self!error("Migration {%m<id>} has no $dialect definition") unless %m<drivers>{$dialect}:exists;
        my $dir = %m<path>.add($dialect);
        my $up = $dir.add('up.sql').slurp;
        my $down = $dir.add('down.sql').slurp;
        my $snapshot = $dir.add('schema.rakuconf').slurp;
        self!error("Modified snapshot: {%m<id>}")
            unless self!checksum($snapshot) eq %m<drivers>{$dialect}<snapshot-checksum>;
        %( |%m, up => statements($up, :$dialect), down => statements($down, :$dialect),
            up-checksum => self!checksum($up), down-checksum => self!checksum($down) )
    }).Array
}
method !validate(@history, @rows, Bool :$allow-unresolved = False) {
    my %known = @history.map({ .<id> => $_ });
    for @rows -> $row {
        self!error("Unresolved migration execution: {$row.id} ({$row.state})")
            unless $allow-unresolved || $row.state eq any(<applied reverted>);
        self!error("Applied migration missing from files: {$row.id}") unless %known{$row.id}:exists;
        my %m = %known{$row.id};
        self!error("Applied migration was modified: {$row.id}")
            unless $row.predecessor eq %m<predecessor>
                && $row.up-checksum eq %m<up-checksum>
                && $row.down-checksum eq %m<down-checksum>;
    }
    my $gap = False;
    for @history -> %m {
        my $applied = @rows.first({ .id eq %m<id> && .state eq 'applied' }).defined;
        self!error('Database migration history has a gap') if $gap && $applied;
        $gap = True unless $applied;
    }
}
method !lock($db, Str $dialect) {
    given $dialect {
        when 'SQLite' {
            $db.execute('PRAGMA foreign_keys = ON');
            my $statement = $db.prepare('BEGIN IMMEDIATE');
            LEAVE { try $statement.statement.finish }
            $statement.execute;
        }
        when 'Pg' {
            my $row = self!row($db, 'SELECT pg_try_advisory_lock(1380271181) AS acquired');
            self!error('Another migration executor holds the database lock') unless $row<acquired>.Str.lc eq any(<1 true t>);
        }
        when 'MySQL' {
            my $row = self!row($db, "SELECT GET_LOCK(CONCAT('red_migrations:', SHA1(DATABASE())), 0) AS acquired");
            self!error('Another migration executor holds the database lock') unless $row<acquired>.Str.lc eq any(<1 true t>);
        }
    }
}
method !unlock($db, Str $dialect) {
    self!execute($db, 'SELECT pg_advisory_unlock(1380271181)') if $dialect eq 'Pg';
    self!execute($db, "SELECT RELEASE_LOCK(CONCAT('red_migrations:', SHA1(DATABASE())))") if $dialect eq 'MySQL';
}
method !preflight($db, Str $dialect, %migration, @history, Bool $rollback) {
    my $index = @history.first(*.<id> eq %migration<id>, :k);
    my $current = Red::Migration::Snapshot.load(
        %migration<path>.add($dialect).add('schema.rakuconf'));
    my $previous = $index > 0
        ?? Red::Migration::Snapshot.load(@history[$index - 1]<path>.add($dialect).add('schema.rakuconf'))
        !! Red::Migration::Snapshot.new;
    my $from = $rollback ?? $current !! $previous;
    my $to = $rollback ?? $previous !! $current;
    self!validate-alterations($db, $dialect, $from, $to)
}
method !validate-alterations($db, Str $dialect, $from, $to) {
    my %old = $from.tables.map({ .name => $_ });
    for $to.tables -> $table {
        next unless %old{$table.name}:exists;
        my %columns = %old{$table.name}.columns.map({ .name => $_ });
        for $table.columns -> $column {
            next unless %columns{$column.name}:exists;
            my $before = %columns{$column.name};
            my $quoted-table = $db.table-name-wrapper($table.name);
            my $quoted-column = $db.table-name-wrapper($column.name);
            if $before.nullable && !$column.nullable {
                my $row = self!row($db,
                    "SELECT COUNT(*) AS red_nulls FROM $quoted-table WHERE $quoted-column IS NULL");
                self!error("Cannot make {$table.name}.{$column.name} NOT NULL: existing NULL values")
                    if $row<red_nulls>;
            }
            if $dialect eq 'MySQL' && ($before.normalized-type ne $column.normalized-type
                    || $before.nullable != $column.nullable) {
                my $row = self!row($db, q:to/SQL/, $table.name, $column.name);
                    SELECT c.COLUMN_DEFAULT AS column_default, c.EXTRA AS extra,
                           c.COLUMN_COMMENT AS comment, c.COLLATION_NAME AS collation_name,
                           t.TABLE_COLLATION AS table_collation
                    FROM information_schema.COLUMNS c
                    JOIN information_schema.TABLES t
                      ON t.TABLE_SCHEMA = c.TABLE_SCHEMA AND t.TABLE_NAME = c.TABLE_NAME
                    WHERE c.TABLE_SCHEMA = DATABASE() AND c.TABLE_NAME = ? AND c.COLUMN_NAME = ?
                    SQL
                self!error("MySQL alteration would lose unmanaged metadata: {$table.name}.{$column.name}")
                    if !$row || $row<column_default>.defined || ($row<extra> // '').Str.chars
                        || ($row<comment> // '').Str.chars
                        || ($row<collation_name>.defined
                            && $row<collation_name> ne $row<table_collation>);
            }
        }
    }
}
method !run(Str $connection, Bool :$rollback = False, Bool :$inspect = False) {
    self!error('Run migrations outside an existing Red transaction') if CALLERS::<$*RED-TRANSACTION-RUNNING>;
    my $locked = False;
    my $pg-open = False;
    my $db = self!connection($connection);
    my $dialect = self!dialect($db);
    my $session;
    if $dialect eq 'Pg' && $db.dbh.^name eq 'DB::Pg' {
        $session = $db.dbh.db;
        $db = $db.new-connection($session);
    }
    LEAVE $session.finish if $session.defined;
    my $*RED-DB = $db;
    my $*RED-TRANSACTION-RUNNING = True;
    my @history = self!scripts(self.history, $dialect);
    self!lock($db, $dialect);
    $locked = True;
    LEAVE { self!unlock($db, $dialect) if $locked }
    my $sqlite-open = $dialect eq 'SQLite';
    CATCH {
        default {
            try $db.execute('ROLLBACK') if $sqlite-open || $pg-open;
            .rethrow;
        }
    }
    Red::Migration::Applied.^create-table(:if-not-exists);
    my @rows = Red::Migration::Applied.^all.List;
    self!validate(@history, @rows, :allow-unresolved($inspect));
    if $inspect {
        my @status = @history.map(-> %m {
            my $row = @rows.first(*.id eq %m<id>);
            %(id => %m<id>, name => %m<name>, state => ($row.defined ?? $row.state !! 'pending'),
                reversible => %m<drivers>{$dialect}<reversible>)
        });
        $db.execute('COMMIT') if $sqlite-open;
        $sqlite-open = False;
        return @status.Array;
    }
    my @pending = $rollback
        ?? @history.grep(-> %m { @rows.first({ .id eq %m<id> && .state eq 'applied' }).defined }).tail(1)
        !! @history.grep(-> %m { !@rows.first({ .id eq %m<id> && .state eq 'applied' }).defined });
    for @pending -> %m {
        self!error("Rollback is unavailable for {%m<id>}: {%m<drivers>{$dialect}<down-reason>}")
            if $rollback && !%m<drivers>{$dialect}<reversible>;
        self!preflight($db, $dialect, %m, @history, $rollback);
        my $transaction = $dialect eq 'Pg';
        $db.execute('BEGIN') if $transaction;
        $pg-open = $transaction;
        my $row = @rows.first(*.id eq %m<id>);
        my %values = id => %m<id>, predecessor => %m<predecessor>,
            up-checksum => %m<up-checksum>, down-checksum => %m<down-checksum>,
            state => 'running', direction => ($rollback ?? 'down' !! 'up'),
            applied-at => '', reverted-at => '', completed-statements => 0;
        if $row.defined {
            $row.state = 'running'; $row.direction = %values<direction>;
            $row.completed-statements = 0; $row.^save;
        } else { $row = Red::Migration::Applied.^create(|%values) }
        my $completed = 0;
        my $current = '';
        try {
            for %m{$rollback ?? 'down' !! 'up'}.list -> $sql {
                $current = $sql;
                self!execute($db, $sql);
                $completed++;
                if $dialect eq 'MySQL' {
                    $row.completed-statements = $completed; $row.^save;
                }
            }
            $row.state = $rollback ?? 'reverted' !! 'applied';
            $row.completed-statements = $completed;
            if $rollback { $row.reverted-at = DateTime.now.Str }
            else { $row.applied-at = DateTime.now.Str }
            $row.^save;
            $db.execute('COMMIT') if $transaction;
            $pg-open = False;
            CATCH {
                default {
                    my $reason = .message;
                    try $db.execute('ROLLBACK') if $transaction;
                    $pg-open = False;
                    if $dialect eq 'MySQL' {
                        $row.state = 'failed';
                        $row.completed-statements = $completed;
                        $row.^save;
                    }
                    self!error("Migration {%m<id>} failed after $completed statements; SQL: $current; $reason");
                }
            }
        }
    }
    $db.execute('COMMIT') if $sqlite-open;
    $sqlite-open = False;
    @pending.elems
}
method apply(Str :$connection = 'default') { self!run($connection) }
method rollback(Str :$connection = 'default') { self!run($connection, :rollback) }
method status(Str :$connection = 'default') { self!run($connection, :inspect) }

method plan(Str :$connection = 'default', Bool :$allow-destructive = True --> Array) {
    my $db = self!connection($connection);
    my $dialect = self!dialect($db);
    my $*RED-DB = $db;
    my $planner = Red::Migration::Planner.new(:driver($db), :$dialect);
    my $target = $planner.capture($!config.model-types);
    my @tables;
    my @existing = $db.schema-reader.tables-names.List;
    for $target.tables -> $table {
        next unless $table.name eq any(@existing);
        my $found = $db.schema-reader.table-definition($table.name);
        if $dialect eq 'Pg' {
            my %automatic;
            my $statement = $db.execute(q:to/SQL/, $table.name);
                SELECT column_name, column_default, is_identity
                FROM information_schema.columns
                WHERE table_schema = current_schema() AND table_name = $1
                SQL
            loop {
                my $row := $statement.row;
                last if $row =:= IterationEnd || !$row;
                %automatic{$row<column_name>} = $row<is_identity> eq 'YES'
                    || ($row<column_default> // '').starts-with('nextval(');
            }
            $statement.finish-transaction;
            $found = $found.clone(:columns($found.columns.map({
                .clone(:auto-increment(so %automatic{.name}))
            }).Array));
        }
        # Index catalog APIs normalize expressions and driver-specific syntax.
        my $model = $!config.model-types.first(*.^table eq $table.name);
        my @catalog = $db.indexes-for-table($table.name);
        my @indexes;
        for $model.^indexes.grep({ !.inline && $db.schema-definition-applies($_) }) -> $index {
            my $same = @catalog.first(*.<name> eq $index.name);
            if $same.defined {
                self!error("Existing index {$index.name} has an incompatible definition")
                    unless $db.index-definition-matches($index, $same);
                @indexes.push: $table.indexes.first(*.<name> eq $index.name);
            }
        }
        self!error("Existing CHECK/EXCLUDE constraints require an explicit migration: {$table.name}")
            if $table.checks;
        @tables.push: $found.clone(:@indexes,
            :constraints($found.constraints.sort(*.join('|')).Array));
    }
    my $old = Red::Migration::Snapshot.new(:@tables);
    my @sql = $planner.diff($old, $target, :$allow-destructive);
    self!validate-alterations($db, $dialect, $old, $target);
    @sql.Array
}

method sync(Str :$connection = 'default', Bool :$allow-destructive = False) {
    my $locked = False;
    self!error('Run synchronization outside an existing Red transaction') if $*RED-TRANSACTION-RUNNING;
    my $db = self!connection($connection);
    my $session;
    if self!dialect($db) eq 'Pg' && $db.dbh.^name eq 'DB::Pg' {
        $session = $db.dbh.db;
        $db = $db.new-connection($session);
    }
    LEAVE $session.finish if $session.defined;
    my $*RED-DB = $db;
    # Share one connection even when its configuration uses a lazy factory.
    my $config = $!config.clone(:connections{ default => $db });
    my @sql = self.WHAT.new(:$config).plan(:$allow-destructive);
    my $dialect = self!dialect($db);
    return 0 unless @sql;
    self!lock($db, $dialect);
    $locked = True;
    LEAVE { self!unlock($db, $dialect) if $locked }
    my $transaction = $dialect ne 'MySQL';
    $db.execute('BEGIN') if $dialect eq 'Pg';
    CATCH {
        default {
            try $db.execute('ROLLBACK') if $transaction;
            .rethrow;
        }
    }
    self!execute($db, $_) for @sql;
    $db.execute('COMMIT') if $transaction;
    @sql.elems
}
