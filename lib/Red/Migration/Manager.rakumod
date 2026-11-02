use Red;
use Red::Migration::Configuration;
use Red::Migration::Snapshot;
use Red::Migration::Planner;
use Red::Migration::Applied;
use Red::Migration::File;
use Red::Migration::SQL;
use Red::Migration::Scripts;
use Red::Migration::Environment;
use Red::Migration::Logical;
use Red::Migration::Storage;
use Red::Migration::Artifact;
use Red::Migration::Data;
use X::Red::Migration;
use UUID;
use nqp;

=head2 Red::Migration::Manager

unit class Red::Migration::Manager;

# Delegate pure translation to the driver's type object, without constructing a
# connection. Driver constructors may connect eagerly (notably MySQL).
#| Provide access to a driver type's pure translation methods while forbidding SQL execution.
class Translation {
    has Mu $.backend is required;
    #| Delegate dialect-specific translation to the backend type without constructing a database
    #| connection.
    method FALLBACK(Str $method, |args) { $!backend."$method"(|args) }
    #| Reject SQL execution through the translation-only adapter. Preparing migration artifacts must
    #| remain offline.
    method execute(|) { X::Red::Migration.new(:reason('Offline translation cannot execute SQL')).throw }
}

has Red::Migration::Configuration $.config is required;

#| Raise X::Red::Migration with an actionable explanation of an invalid migration or execution
#| state.
method !error(Str $reason) { X::Red::Migration.new(:$reason).throw }
#| Compute the integrity fingerprint used for historical snapshots, source files and generated SQL.
method !checksum(Str $source --> Str) { nqp::sha1($source) }
#| Execute one SQL statement and finish its cursor before committing or releasing the connection.
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
#| Execute a query with bind values, return its first row and release the result cursor.
method !row($db, Str $sql, *@bind) {
    my $statement = $db.execute($sql, |@bind);
    LEAVE $statement.finish-transaction;
    $statement.row
}
#| Load a trusted Raku configuration artifact and extract its plain migration metadata when
#| applicable.
method !load(IO() $path) {
    use MONKEY-SEE-NO-EVAL;
    my $value = EVALFILE $path.absolute;
    $value.^can('artifact-data') ?? $value.artifact-data !! $value
}
#| Resolve a supported SQL backend for offline translation; no target connection is constructed.
method !driver(Str $name) {
    self!error("Unsupported migration driver: $name") unless $name eq any(<SQLite Pg MySQL>);
    require ::("Red::Driver::$name");
    Translation.new(:backend(::("Red::Driver::$name")))
}
#| Resolve a configured connection or lazy factory. A disposable test context overrides the normal
#| target.
method !connection(Str $name) {
    return test-database() if %*ENV<RED_MIGRATION_TEST>;
    my $db = $!config.connections{$name};
    $db = $db() if $db ~~ Callable;
    self!error("Unknown configured connection: $name") unless $db ~~ Red::Driver:D;
    $db
}
#| Return the supported migration dialect for a concrete database driver, rejecting unsupported
#| backends.
method !dialect($db --> Str) {
    my $name = $db.driver-name.split('::').tail;
    self!error("Unsupported migration connection: $name") unless $name eq any(<SQLite Pg MySQL>);
    $name
}
#| Generate a 26-character migration identifier from the current millisecond timestamp and random
#| UUID bits. Ancestry, rather than identifier order, determines execution order.
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
#| Return prepared versions in predecessor order under the history lock. Unfinished drafts are
#| excluded; forks, gaps and invalid artifacts raise X::Red::Migration.
method history(--> Array) {
    with-history-lock($!config.directory, { self!history })
}
#| Build the single predecessor chain from prepared manifests. Call while holding the filesystem
#| history lock.
method !history(--> Array) {
    return [] unless $!config.directory.d;
    my @versions = self!entries.grep({ (.<state> // '') ne 'draft' });
    # Follow ancestry, not filename order.
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
#| Read version directories and validate manifest formats and identifiers. Includes drafts so
#| callers can report or reject unfinished work.
method !entries(--> Array) {
    my @versions;
    return [] unless $!config.directory.d;
    for $!config.directory.dir.grep({ .d && !.basename.starts-with('.') }).sort(*.basename) -> $dir {
        my $file = $dir.add('migration.rakuconf');
        self!error("Missing migration manifest: $file") unless $file.f;
        my %m = self!load($file);
        self!error("Experimental job migrations are no longer supported: $file")
            if (%m<format> // 0) == 3;
        self!error("Unsupported migration format: $file") unless (%m<format> // 0) == any(1, 2);
        self!error("Invalid migration ID: $file") unless (%m<id> // '') ~~ /^ <[0..9A..Z]> ** 26 $/;
        self!error("Duplicate migration ID: {%m<id>}") if @versions.grep(*.<id> eq %m<id>);
        %m<path> = $dir;
        @versions.push: %m;
    }
    @versions.Array
}
#| Generate SQL for every configured driver from the last prepared snapshot, or compile a named
#| draft. Missing dialect history is backfilled first; destructive changes require
#| allow-destructive.
method prepare(Str $name, Bool :$allow-destructive = False) {
    with-history-lock($!config.directory, {
        my @drafts = self!entries.grep({ (.<state> // '') eq 'draft'
            && $name eq any(.<id>, .<name>, .<path>.basename) });
        self!error("Ambiguous migration draft: $name") if @drafts.elems > 1;
        return self!prepare-draft(@drafts[0], :$allow-destructive) if @drafts;
        my @history = self!history;
        my @missing = $!config.drivers.grep(-> $driver {
            @history.grep({ !(.<drivers>{$driver}:exists) }).elems
        });
        if @missing {
            my $stage = staging-history($!config.directory);
            LEAVE discard-staging-history($stage) if $stage.defined;
            my $config = $!config.clone(:directory($stage));
            my $manager = self.WHAT.new(:$config);
            $manager.backfill(:driver($_)) for @missing;
            my $path = $manager.prepare($name, :$allow-destructive);
            $manager.test(:driver($_)) for @missing;
            publish-history($!config.directory, $stage);
            return $path.defined ?? $!config.directory.add($path.basename) !! Nil;
        }
        self!prepare($name, :$allow-destructive)
    }, :!wait)
}
#| Create an offline draft containing frozen previous and target schemas plus migration.raku.
#| Returns its directory without creating driver SQL or opening target databases.
method create(Str $name) {
    with-history-lock($!config.directory, {
        self!error('Migration name must contain letters, digits, underscores or hyphens')
            unless $name ~~ /^ <[A..Za..z0..9_-]>+ $/;
        self!error('Configure at least one model and driver') unless $!config.model-types && $!config.drivers;
        self!error('Duplicate configured drivers') unless $!config.drivers.unique.elems == $!config.drivers.elems;
        my @history = self!history;
        my %snapshots;
        for $!config.drivers -> $dialect {
            %snapshots{$dialect} = Red::Migration::Planner.new(
                :driver(self!driver($dialect)), :$dialect).capture($!config.model-types);
        }
        my $target = logical-capture($!config.model-types, %snapshots, $!config.drivers);
        my $before = @history ?? self!logical(@history.tail) !! Red::Migration::Snapshot.new;
        my $id = self!id;
        make-directory($!config.directory);
        my $stage = $!config.directory.add(".{$id}-draft");
        $stage.mkdir;
        LEAVE remove-tree($stage) if $stage.defined && $stage.e;
        $stage.add('before.rakuconf').spurt($before.source);
        $stage.add('schema.rakuconf').spurt($target.source);
        $stage.add('migration.raku').spurt(data-template($before, $target));
        $stage.add('migration.rakuconf').spurt(artifact-source('manifest', %(
            format => 2, state => 'draft', :$id, :$name,
            predecessor => (@history ?? @history.tail<id> !! ''),
            logical-checksum => self!checksum($target.source),
            before-checksum => self!checksum($before.source))));
        my $path = $!config.directory.add("$id-$name");
        $stage.rename($path);
        $path
    }, :!wait)
}

#| Validate a draft predecessor and snapshots, compile its data declarations and publish all dialect
#| artifacts atomically. Explicit driver overrides replace automatic SQL generation.
method !prepare-draft(%draft, Bool :$allow-destructive = False) {
    my @history = self!history;
    self!error('Draft predecessor changed; recreate or rebase the draft')
        unless %draft<predecessor> eq (@history ?? @history.tail<id> !! '');
    for $!config.drivers -> $driver {
        self.backfill(:$driver) if @history.grep({ !(.<drivers>{$driver}:exists) });
    }
    my $path = %draft<path>;
    self!error('Draft snapshots changed; create a new draft from the models')
        unless self!checksum($path.add('schema.rakuconf').slurp) eq %draft<logical-checksum>
            && self!checksum($path.add('before.rakuconf').slurp) eq %draft<before-checksum>;
    my $before = Red::Migration::Snapshot.load($path.add('before.rakuconf'));
    my $target = Red::Migration::Snapshot.load($path.add('schema.rakuconf'));
    my $source = $path.add('migration.raku').slurp;
    my $stage = $!config.directory.parent.add('.' ~ $!config.directory.basename ~ '-prepare-' ~ %draft<id>);
    copy-tree($path, $stage);
    LEAVE remove-tree($stage) if $stage.defined && $stage.e;
    my %drivers;
    for $!config.drivers -> $dialect {
        my $directory = $stage.add($dialect);
        my $override = $directory.add('overrides.rakuconf');
        if $override.f && (self!load($override)<manual> // False) {
            %drivers{$dialect} = self!variant($directory, $before, $target, $dialect, :manual);
        } else {
            self!error("Unregistered $dialect SQL requires explicit manual overrides: $directory")
                if $directory.e;
            %drivers{$dialect} = self!data-variant($directory, $before, $target,
                $source, $dialect, :$allow-destructive);
        }
    }
    my %manifest = %draft;
    %manifest<path>:delete;
    %manifest<state> = 'prepared';
    %manifest<drivers> = %drivers;
    %manifest<data-checksum> = self!checksum($source);
    $stage.add('operations.rakuconf').spurt(artifact-source('operations',
        changes(schema-data($before), schema-data($target))));
    $stage.add('migration.rakuconf').spurt(artifact-source('manifest', %manifest));
    my $publication = staging-history($!config.directory);
    LEAVE discard-staging-history($publication) if $publication.defined && $publication.e;
    remove-tree($publication.add($path.basename));
    $stage.rename($publication.add($path.basename));
    publish-history($!config.directory, $publication);
    $path
}

#| Compile one dialect into ordered structural additions, data statements and final constraints.
#| Generate the structural inverse and require explicit review of data reversibility.
method !data-variant(IO::Path $directory, $before, $after, Str $source, Str $dialect,
                     Bool :$allow-destructive = True --> Hash) {
    my $driver = self!driver($dialect);
    my $old = translate-logical($before, $driver, $dialect, $!config.type-mappings{$dialect} // {});
    my $new = translate-logical($after, $driver, $dialect, $!config.type-mappings{$dialect} // {});
    my $middle = intermediate-schema($old, $new);
    my %data = compile-data($old, $new, $source, $driver, $dialect);
    my $planner = Red::Migration::Planner.new(:$driver, :$dialect);
    my @before = $planner.diff($old, $middle, :$allow-destructive);
    my @after = $planner.diff($middle, $new, :$allow-destructive);
    my @down;
    my $reason = '';
    try {
        @down = $planner.diff($new, $old, :allow-destructive);
        CATCH { when X::Red::Migration { $reason = .message } }
    }
    $reason = 'Data transformations require an explicit inverse or an irreversible declaration'
        if !$reason && %data<sql>.elems;
    make-directory($directory);
    my $number = 0;
    for (@before.Array => 'structure', %data<sql>.Array => 'data', @after.Array => 'constraints') -> $part {
        next unless $part.key.elems;
        make-directory($directory.add('up'));
        $directory.add('up/' ~ (++$number).fmt('%03d') ~ '-' ~ $part.value ~ '.sql')
            .spurt($part.key.map(* ~ ';').join("\n\n") ~ "\n");
    }
    write-direction($directory, 'up', "\n") unless $directory.add('up').d;
    write-direction($directory, 'down', @down.map(* ~ ';').join("\n\n") ~ "\n");
    $directory.add('schema.rakuconf').spurt($new.source);
    my %metadata = reversible => !$reason, down-state => ($reason ?? 'pending' !! 'available'),
        down-reason => $reason, snapshot-checksum => self!checksum($new.source),
        generated-mode => 'statements-v1',
        generated-up => read-direction($directory, 'up', $dialect)<checksum>,
        generated-down => read-direction($directory, 'down', $dialect)<checksum>;
    %metadata<generated-up> = self!checksum(read-direction($directory, 'up', $dialect)<sql>.Array.raku);
    %metadata<generated-down> = self!checksum(read-direction($directory, 'down', $dialect)<sql>.Array.raku);
    %metadata
}
#| Prepare an ordinary structural version from configured models. An empty difference returns Nil;
#| changes needing data preparation direct the caller to create a draft.
method !prepare(Str $name, Bool :$allow-destructive = False) {
    self!error('Migration name must contain letters, digits, underscores or hyphens')
        unless $name ~~ /^ <[A..Za..z0..9_-]>+ $/;
    self!error('Configure at least one model and driver') unless $!config.model-types && $!config.drivers;
    self!error('Duplicate configured drivers') unless $!config.drivers.unique.elems == $!config.drivers.elems;
    $!config.directory.mkdir unless $!config.directory.d;
    my @history = self.history;
    my $previous = @history ?? @history.tail<id> !! '';
    my %artifacts;
    my %snapshots;
    my %drivers;
    my $changed = False;
    for $!config.drivers.sort -> $dialect {
        self!scripts(@history, $dialect) if @history;
        my $db = self!driver($dialect);
        my $planner = Red::Migration::Planner.new(:driver($db), :$dialect);
        my $new = $planner.capture($!config.model-types);
        %snapshots{$dialect} = $new;
        my $old = Red::Migration::Snapshot.new;
        if @history {
            my $file = @history.tail<path>.add($dialect).add('schema.rakuconf');
            self!error("Previous migration has no $dialect snapshot") unless $file.f;
            self!error("Modified snapshot: $file")
                unless self!checksum($file.slurp) eq @history.tail<drivers>{$dialect}<snapshot-checksum>;
            $old = Red::Migration::Snapshot.load($file);
        }
        my @required = required-columns($old, $new);
        self!error("Columns require data preparation: " ~ @required.map({ .<table> ~ '.' ~ .<column> }).join(', ')
            ~ ". Run `red migration create $name`, complete migration.raku, then run `red migration prepare $name`.") if @required;
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
            snapshot-checksum => self!checksum($source),
            down-state => ($reason ?? 'pending' !! 'available'),
            generated-mode => 'statements-v1',
            generated-up => self!checksum(statements(%artifacts{$dialect}<up>, :$dialect).raku),
            generated-down => self!checksum(statements(%artifacts{$dialect}<down>, :$dialect).raku));
    }
    return Nil unless $changed;
    my $logical = logical-capture($!config.model-types, %snapshots, $!config.drivers);
    my $logical-source = $logical.source;
    my %before = tables => {};
    if @history && @history.tail<path>.add('schema.rakuconf').f {
        %before = schema-data(Red::Migration::Snapshot.load(@history.tail<path>.add('schema.rakuconf')));
    }
    my @operations = changes(%before, schema-data($logical));
    my $id = self!id;
    my %manifest = format => 2, :$id, :$name, predecessor => $previous, :%drivers, logical-checksum => self!checksum($logical-source);
    $!config.directory.mkdir unless $!config.directory.d;
    my $staging = $!config.directory.add(".$id-{$*PID}");
    $staging.mkdir;
    # Publish only after all dialects have generated and validated successfully.
    for %artifacts.keys.sort -> $dialect {
        my $dir = $staging.add($dialect); $dir.mkdir;
        $dir.add('schema.rakuconf').spurt: %artifacts{$dialect}<snapshot>;
        write-direction($dir, 'up', %artifacts{$dialect}<up>);
        write-direction($dir, 'down', %artifacts{$dialect}<down>);
    }
    $staging.add('schema.rakuconf').spurt($logical-source);
    $staging.add('operations.rakuconf').spurt(artifact-source('operations', @operations));
    $staging.add('migration.rakuconf').spurt: artifact-source('manifest', %manifest);
    my $path = $!config.directory.add("$id-$name");
    my @current = self.history;
    self!error('Migration history changed during preparation; retry')
        unless (@current ?? @current.tail<id> !! '') eq $previous;
    $staging.rename($path);
    $path
}
#| Validate frozen source and schema fingerprints, then read each direction into ordered statements
#| and file checkpoints for execution.
method !scripts(@history, Str $dialect --> Array) {
    @history.map(-> %m {
        if %m<data-checksum>:exists {
            self!error("Modified migration.raku: {%m<id>}") unless self!checksum(
                %m<path>.add('migration.raku').slurp) eq %m<data-checksum>;
            self!error("Modified previous snapshot: {%m<id>}") unless self!checksum(
                %m<path>.add('before.rakuconf').slurp) eq %m<before-checksum>;
        }
        self!error("Migration {%m<id>} has no $dialect definition") unless %m<drivers>{$dialect}:exists;
        my $dir = %m<path>.add($dialect);
        my %up = read-direction($dir, 'up', $dialect);
        my %down = read-direction($dir, 'down', $dialect);
        my $snapshot = $dir.add('schema.rakuconf').slurp;
        self!error("Modified snapshot: {%m<id>}")
            unless self!checksum($snapshot) eq %m<drivers>{$dialect}<snapshot-checksum>;
        %( |%m, up => %up<sql>, down => %down<sql>,
            up-instructions => %up<instructions>, down-instructions => %down<instructions>,
            up-files => %up<files>, down-files => %down<files>,
            up-checksum => %up<checksum>, down-checksum => %down<checksum> )
    }).Array
}
#| Compare database execution records with the prepared chain. Reject modified or missing executed
#| versions, unresolved failures and gaps in applied history.
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
#| Acquire the dialect-specific migration lock. SQLite opens a transaction; PostgreSQL and MySQL use
#| database-scoped advisory or named locks.
method !lock($db, Str $dialect, Bool :$read-only = False) {
    given $dialect {
        when 'SQLite' {
            $db.execute('PRAGMA foreign_keys = ON') unless $read-only;
            my $statement = $db.prepare($read-only ?? 'BEGIN' !! 'BEGIN IMMEDIATE');
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
#| Release native advisory or named migration locks. SQLite transaction completion is handled by the
#| executor.
method !unlock($db, Str $dialect) {
    self!execute($db, 'SELECT pg_advisory_unlock(1380271181)') if $dialect eq 'Pg';
    self!execute($db, "SELECT RELEASE_LOCK(CONCAT('red_migrations:', SHA1(DATABASE())))") if $dialect eq 'MySQL';
}
#| Inspect the source and target snapshots before execution and reject unsafe alterations. NULL
#| checks are deferred until their constraint statement so earlier data updates can run.
method !preflight($db, Str $dialect, %migration, @history, Bool $rollback) {
    my $index = @history.first(*.<id> eq %migration<id>, :k);
    my $current = Red::Migration::Snapshot.load(
        %migration<path>.add($dialect).add('schema.rakuconf'));
    my $previous = $index > 0
        ?? Red::Migration::Snapshot.load(@history[$index - 1]<path>.add($dialect).add('schema.rakuconf'))
        !! Red::Migration::Snapshot.new;
    my $from = $rollback ?? $current !! $previous;
    my $to = $rollback ?? $previous !! $current;
    self!validate-alterations($db, $dialect, $from, $to, :!check-nulls)
}
#| Check nullable tightening and metadata-sensitive changes against the actual database. An optional
#| statement restricts checks to the ALTER TABLE currently being executed.
method !validate-alterations($db, Str $dialect, $from, $to,
                            Bool :$check-nulls = True, Str :$statement) {
    my %old = $from.tables.map({ .name => $_ });
    for $to.tables -> $table {
        next unless %old{$table.name}:exists;
        my %columns = %old{$table.name}.columns.map({ .name => $_ });
        for $table.columns -> $column {
            next unless %columns{$column.name}:exists;
            my $before = %columns{$column.name};
            my $quoted-table = $db.table-name-wrapper($table.name);
            my $quoted-column = $db.table-name-wrapper($column.name);
            next if $statement.defined && (!$statement.starts-with("ALTER TABLE $quoted-table ")
                || !$statement.contains($quoted-column));
            if $check-nulls && $before.nullable && !$column.nullable {
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
#| Apply, revert or inspect a validated migration chain on a pinned connection. Maintain per-version
#| and per-file checkpoints, with transactional behavior appropriate to the selected dialect.
method !run(Str $connection, Bool :$rollback = False, Bool :$inspect = False,
            Bool :$report = False, Str :$to) {
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
    self!error('Unprepared migration drafts exist; run red migration prepare first')
        if !$inspect && self!entries.grep({ (.<state> // '') eq 'draft' });
    self!lock($db, $dialect, :read-only($inspect));
    $locked = True;
    LEAVE { self!unlock($db, $dialect) if $locked }
    my $sqlite-open = $dialect eq 'SQLite';
    CATCH {
        default {
            try $db.execute('ROLLBACK') if $sqlite-open || $pg-open;
            .rethrow;
        }
    }
    my @tables = $inspect ?? $db.schema-reader.tables-names.grep(*.defined).List !! ();
    my $initialized = $inspect ?? so ('red_migrations' eq any(@tables)) !! True;
    unless $inspect {
        Red::Migration::Applied.^create-table(:if-not-exists);
        Red::Migration::File.^create-table(:if-not-exists);
    }
    my @rows = $initialized ?? Red::Migration::Applied.^all.List !! ();
    self!validate(@history, @rows, :allow-unresolved($inspect));
    if $inspect {
        my @status = @history.map(-> %m {
            my $row = @rows.first(*.id eq %m<id>);
            %(id => %m<id>, name => %m<name>, state => ($row.defined ?? $row.state !! 'pending'),
                reversible => %m<drivers>{$dialect}<reversible>)
        });
        my %report;
        if $report {
            my @models = $!config.model-types.map(-> $model {
                my @columns = $model.^columns.map({
                    my $column = .column;
                    %(name => $column.name, raku-type => $column.attr.type.^name,
                        nullable => $column.nullable, primary-key => $column.id,
                        auto-increment => $column.auto-increment)
                });
                %(name => $model.^name, table => $model.^table,
                    table-exists => so ($model.^table eq any(@tables)), columns => @columns.Array)
            });
            %report = :$initialized, :$connection, driver => $dialect,
                directory => $!config.directory.absolute.Str, models => @models.Array,
                migrations => @status.Array, recorded => @rows.elems;
            %report<drafts> = self!entries.grep({ (.<state> // '') eq 'draft' }).map({
                %(id => .<id>, name => .<name>, state => 'draft')
            }).Array;
        }
        $db.execute('COMMIT') if $sqlite-open;
        $sqlite-open = False;
        return $report ?? %report !! @status.Array;
    }
    my @pending = $rollback
        ?? @history.grep(-> %m { @rows.first({ .id eq %m<id> && .state eq 'applied' }).defined }).tail(1)
        !! @history.grep(-> %m { !@rows.first({ .id eq %m<id> && .state eq 'applied' }).defined });
    if $to.defined {
        my $index = @history.first(*.<id> eq $to, :k);
        self!error("Unknown migration target: $to") unless $index.defined;
        my %allowed = set @history[^($index + 1)].map(*.<id>);
        @pending = @pending.grep({ %allowed{.<id>} });
    }
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
        my $file-record;
        my $file-name = '';
        my @file-records = Red::Migration::File.^all.List;
        my %records;
        my %totals;
        my @instructions = %m{$rollback ?? 'down-instructions' !! 'up-instructions'}.list;
        %totals{.<file>}++ for @instructions;
        try {
            for %m{$rollback ?? 'down-files' !! 'up-files'}.list -> %file {
                my $key = nqp::sha1(%m<id> ~ '|' ~ %values<direction> ~ '|' ~ %file<file>);
                my $record = @file-records.first(*.id eq $key);
                my $state = %totals{%file<file>} ?? 'pending' !! 'applied';
                if $record.defined {
                    self!error("Previously executed file changed: {%file<file>}")
                        unless $record.checksum eq %file<checksum>;
                    $record.state = $state;
                    $record.completed-statements = 0;
                    $record.^save;
                } else {
                    $record = Red::Migration::File.^create(:id($key),
                        :migration-id(%m<id>), :direction(%values<direction>),
                        :file(%file<file>), :checksum(%file<checksum>),
                        :$state, :completed-statements(0));
                }
                %records{%file<file>} = $record;
            }
            for @instructions -> %instruction {
                my $sql = %instruction<sql>;
                $file-record = %records{%instruction<file>};
                if $file-name ne %instruction<file> {
                    $file-name = %instruction<file>;
                    $file-record.state = 'running';
                    $file-record.^save;
                }
                $current = "{%instruction<file>}:{%instruction<statement>}: $sql";
                if $sql.uc.contains('NOT NULL') && $sql.uc.starts-with('ALTER TABLE ') {
                    my $target = Red::Migration::Snapshot.load(%m<path>.add("$dialect/schema.rakuconf"));
                    my $actual = Red::Migration::Snapshot.new(:tables($target.tables.map({
                        $db.schema-reader.table-definition(.name)
                    }).Array));
                    self!validate-alterations($db, $dialect, $actual, $target, :statement($sql));
                }
                self!execute($db, $sql);
                $completed++;
                $file-record.completed-statements = %instruction<statement>;
                $file-record.state = %instruction<statement> == %totals{$file-name} ?? 'applied' !! 'running';
                $file-record.^save;
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
                        if $file-record.defined { $file-record.state = 'failed'; $file-record.^save }
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
#| Synchronously apply pending versions to the selected connection, optionally stopping at a target
#| ID. Return the number applied; recorded versions are not executed again.
method apply(Str :$connection = 'default', Str :$to) {
    with-history-lock($!config.directory, { self!run($connection, :$to) })
}
#| Synchronously execute the latest non-reverted version in the down direction. Refuse unavailable
#| inverses; structural rollback does not restore discarded data.
method rollback(Str :$connection = 'default') {
    with-history-lock($!config.directory, { self!run($connection, :rollback) })
}
#| Return migration identities, names and database execution states without creating history tables
#| or changing application schemas.
method status(Str :$connection = 'default') {
    with-history-lock($!config.directory, { self!run($connection, :inspect) })
}
#| Return initialization, connection, model, migration and draft details for CLI reporting. This is
#| an inspection operation and does not initialize migration history.
method status-report(Str :$connection = 'default' --> Hash) {
    with-history-lock($!config.directory, { self!run($connection, :inspect, :report) })
}

#| Compare configured models with the live database and return supported SQL changes without
#| executing them. This differs from prepare, which compares historical snapshots.
method plan(Str :$connection = 'default', Bool :$allow-destructive = True, Bool :$validation = False --> Array) {
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
            if $table.checks && !$validation;
        @tables.push: $found.clone(:@indexes,
            :checks($validation ?? $table.checks !! $found.checks),
            :constraints($found.constraints.sort(*.join('|')).Array));
    }
    my $old = Red::Migration::Snapshot.new(:@tables);
    my @sql = $planner.diff($old, $target, :$allow-destructive);
    self!validate-alterations($db, $dialect, $old, $target);
    @sql.Array
}

#| Apply the live development schema plan without advancing versioned history. Destructive changes
#| require explicit opt-in; callers must not run inside an existing Red transaction.
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

#| Validate history in fresh disposable databases, including schema verification, reversible
#| rollback and reapplication. Optional fixtures run after a selected prefix; a child command
#| receives the isolated test connection. Pending inverse implementations fail validation.
method test(Str :$driver, :@command = [], Bool :$keep = False, Callable :$fixtures, Str :$fixture-after, Bool :$compare-models = True) {
    self!error('Unprepared migration drafts exist; run red migration prepare first')
        if self!entries.grep({ (.<state> // '') eq 'draft' });
    my @versions = self.history; # Validate ancestry before provisioning anything.
    my @drivers = $driver.defined ?? ($driver,) !! $!config.drivers;
    self!error('Select exactly one driver when running a child command') if @command && @drivers != 1;
    for @drivers -> $dialect {
        for @versions -> %version {
            self!error("Rollback implementation pending: {%version<id>}")
                if (%version<drivers>{$dialect}<down-state> // 'available') eq 'pending';
        }
        temporary-database($dialect, $!config.test-servers{$dialect} // {},
            -> $db, $context, %parameters {
                my $config = $!config.clone(:connections{ default => $db });
                my $manager = self.WHAT.new(:$config);
                my $fixture-target = $fixture-after // (@versions ?? @versions.head<id> !! '');
                self!error('Fixtures require a known migration target')
                    if $fixtures.defined && !@versions.first(*.<id> eq $fixture-target).defined;
                for @versions -> %version {
                    $manager.apply(:to(%version<id>));
                    $manager.verify(:connection<default>);
                    $fixtures($db, $manager)
                        if $fixtures.defined && %version<id> eq $fixture-target;
                }
                $manager.apply unless @versions;
                my @pending = $manager.status.grep(*.<state> ne 'applied');
                self!error('Test database has unapplied migrations') if @pending;
                $manager.verify(:connection<default>);
                if $compare-models {
                    my @remaining;
                    try {
                        @remaining = $manager.plan(:validation);
                        CATCH { when X::Red::Migration {
                            self!error("Migrated database does not match configured models: {.reason}");
                        } }
                    }
                    self!error('Migrated database does not match configured models') if @remaining;
                }
                my %child-environment = %*ENV;
                if @command {
                    my %*ENV = %child-environment;
                    my @libraries = $*REPO.repo-chain.grep(*.^name eq 'CompUnit::Repository::FileSystem')
                        .map(*.prefix.Str);
                    %*ENV<RAKULIB> = (|@libraries, |(%*ENV<RAKULIB> // '').split(','))
                        .grep(*.chars).unique.join(',');
                    %*ENV<RED_MIGRATION_TEST> = $context.Str;
                    %*ENV<RED_DATABASE> = ($dialect, |%parameters.pairs.map({ .key ~ '=' ~ .value })).join(' ');
                    my $child = run |@command;
                    self!error("Child command failed with exit code {$child.exitcode}") if $child.exitcode;
                }
                my @history = $manager.history;
                my %tested-down;
                for @history.reverse -> %migration {
                    self!error("Rollback implementation pending: {%migration<id>}")
                        if (%migration<drivers>{$dialect}<down-state> // 'available') eq 'pending';
                    last unless %migration<drivers>{$dialect}<reversible>;
                    $manager.rollback;
                    %tested-down{%migration<id>} = True;
                    $manager.verify(:connection<default>);
                }
                $manager.apply;
                # A declared irreversible version stops the main rollback chain.
                # Exercise earlier reversible versions against their own prefixes.
                for @history.grep({ .<drivers>{$dialect}<reversible> && !%tested-down{.<id>} }) -> %version {
                    temporary-database($dialect, $!config.test-servers{$dialect} // {},
                        -> $prefix-db, $prefix-context, %prefix-parameters {
                            my $prefix = self.WHAT.new(:config(
                                $!config.clone(:connections{ default => $prefix-db })));
                            $prefix.apply(:to(%version<id>));
                            $prefix.rollback;
                            $prefix.verify(:connection<default>);
                            $prefix.apply(:to(%version<id>));
                        });
                }
                True
            }, :$keep);
    }
    True
}

#| Load a version logical schema after checking its fingerprint. Portable history is required for
#| automatic backfill and serialization.
method !logical(%migration --> Red::Migration::Snapshot) {
    my $file = %migration<path>.add('schema.rakuconf');
    self!error("Migration {%migration<id>} needs a logical schema snapshot before backfill or serialization")
        unless $file.f && %migration<logical-checksum>.defined;
    self!error("Modified logical snapshot: $file")
        unless self!checksum($file.slurp) eq %migration<logical-checksum>;
    Red::Migration::Snapshot.load($file)
}
#| Check whether both SQL directions still match their generated fingerprints. Custom SQL cannot be
#| silently regenerated for another driver or predecessor.
method !generated(%migration, Str $driver --> Bool) {
    self!data-source(%migration);
    my %metadata = %migration<drivers>{$driver};
    return False unless %metadata<generated-up>.defined && %metadata<generated-down>.defined;
    my $path = %migration<path>.add($driver);
    for <up down> -> $direction {
        my %script = read-direction($path, $direction, $driver);
        my $hash;
        if (%metadata<generated-mode> // '') eq 'statements-v1' {
            $hash = self!checksum(%script<sql>.list.Array.raku);
        } else {
            return False unless %script<files>.elems == 1;
            $hash = %script<files>[0]<checksum>;
        }
        return False unless $hash eq %metadata{"generated-$direction"};
    }
    True
}
#| Return a version frozen transformation source after validating its source and previous-schema
#| checksums. Versions without data declarations return the undefined Str type.
method !data-source(%migration) {
    return Str unless %migration<data-checksum>:exists;
    my $source = %migration<path>.add('migration.raku').slurp;
    self!error("Modified migration.raku: {%migration<id>}")
        unless self!checksum($source) eq %migration<data-checksum>;
    self!error("Modified previous snapshot: {%migration<id>}")
        unless self!checksum(%migration<path>.add('before.rakuconf').slurp) eq %migration<before-checksum>;
    $source
}
#| Produce one driver schema and SQL directions from portable snapshots, data declarations or
#| complete manual overrides. Record generated fingerprints and inverse availability.
method !variant(IO() $directory, $before, $after, Str $driver,
                Bool :$manual = False, Str :$data --> Hash) {
    if $data.defined && !$manual {
        return self!data-variant($directory.IO, $before, $after, $data, $driver);
    }
    my $backend = self!driver($driver);
    my $old = $manual ?? Red::Migration::Snapshot.new
        !! translate-logical($before, $backend, $driver, $!config.type-mappings{$driver} // {});
    my $snapshot-file = $directory.add('schema.rakuconf');
    my $new = $manual && $snapshot-file.f ?? Red::Migration::Snapshot.load($snapshot-file)
        !! translate-logical($after, $backend, $driver, $!config.type-mappings{$driver} // {});
    make-directory($directory);
    my %metadata;
    if !$manual {
        my $planner = Red::Migration::Planner.new(:driver($backend), :dialect($driver));
        my @up = $planner.diff($old, $new, :allow-destructive);
        my @down;
        my $reason = '';
        try {
            @down = $planner.diff($new, $old, :allow-destructive);
            CATCH { when X::Red::Migration { $reason = .message } }
        }
        my $up = @up.map(* ~ ';').join("\n\n") ~ "\n";
        my $down = $reason ?? "-- Rollback pending: $reason\n" !! @down.map(* ~ ';').join("\n\n") ~ "\n";
        write-direction($directory, 'up', $up);
        write-direction($directory, 'down', $down);
        %metadata = reversible => !$reason, down-state => ($reason ?? 'pending' !! 'available'),
            down-reason => $reason, generated-mode => 'statements-v1',
            generated-up => self!checksum(statements($up, :dialect($driver)).raku),
            generated-down => self!checksum(statements($down, :dialect($driver)).raku);
    } else {
        my %overrides = self!load($directory.add('overrides.rakuconf'));
        self!error('Manual backfill must explicitly declare down-state')
            unless (%overrides<down-state> // '') eq any(<available irreversible>);
        %metadata = reversible => %overrides<down-state> eq 'available',
            down-state => %overrides<down-state>, down-reason => (%overrides<reason> // '');
        make-directory($directory.add('down')) if %overrides<down-state> eq 'irreversible';
    }
    if !$manual && $directory.add('overrides.rakuconf').f {
        my %override = self!load($directory.add('overrides.rakuconf'));
        if (%override<down-state> // '') eq 'irreversible' {
            %metadata<down-state> = 'irreversible';
            %metadata<reversible> = False;
            %metadata<down-reason> = %override<reason> // 'Explicitly irreversible';
        }
    }
    read-direction($directory, $_, $driver) for <up down>;
    my $source = $new.source;
    $directory.add('schema.rakuconf').spurt($source);
    %metadata<snapshot-checksum> = self!checksum($source);
    %metadata
}
#| Generate and validate a missing driver variant for every prepared historical version. Preserve
#| version IDs and existing dialects, and publish only after the staged history passes validation.
method backfill(Str :$driver!) {
    with-history-lock($!config.directory, {
        my @history = self!history;
        return 0 unless @history;
        return 0 unless @history.grep({ !(.<drivers>{$driver}:exists) });
        my $stage = staging-history($!config.directory);
        LEAVE discard-staging-history($stage) if $stage.defined;
        my $previous = Red::Migration::Snapshot.new;
        my $count = 0;
        for @history -> %migration {
            my $logical = self!logical(%migration);
            unless %migration<drivers>{$driver}:exists {
                my $target = $stage.add(%migration<path>.basename);
                my $directory = $target.add($driver);
                my $has-overrides = $directory.add('overrides.rakuconf').f;
                my %override = $has-overrides ?? self!load($directory.add('overrides.rakuconf')) !! {};
                my $manual = so (%override<manual> // False);
                for %migration<drivers>.keys -> $source {
                    self!error("Migration {%migration<id>} has custom SQL; provide $driver overrides")
                        unless $manual || self!generated(%migration, $source);
                }
                self!error("Unregistered $driver files need overrides.rakuconf: $directory")
                    if $directory.e && !$has-overrides;
                my %metadata = self!variant($directory, $previous, $logical, $driver, :$manual,
                    :data(self!data-source(%migration)));
                if %migration<drivers>.values.first({ (.<down-state> // '') eq 'irreversible' }).defined {
                    %metadata<down-state> = 'irreversible';
                    %metadata<reversible> = False;
                    %metadata<down-reason> = 'Explicitly irreversible';
                } elsif (%metadata<down-reason> // '').starts-with('Data transformations require')
                        && %migration<drivers>.values.first({
                            (.<down-state> // '') eq 'available' && .<reversible>
                        }).defined {
                    %metadata<down-state> = 'available';
                    %metadata<reversible> = True;
                    %metadata<down-reason> = '';
                }
                my %manifest = self!load($target.add('migration.rakuconf'));
                %manifest<drivers>{$driver} = %metadata;
                $target.add('migration.rakuconf').spurt(artifact-source('manifest', %manifest));
                $count++;
            }
            $previous = $logical;
        }
        my $prepared = staging-history($stage);
        LEAVE discard-staging-history($prepared) if $prepared.defined;
        for $prepared.dir.grep({ .d && .add('migration.rakuconf').f }) -> $entry {
            remove-tree($entry) if (self!load($entry.add('migration.rakuconf'))<state> // '') eq 'draft';
        }
        my $config = $!config.clone(:directory($prepared));
        self.WHAT.new(:$config).test(:$driver, :!compare-models);
        publish-history($!config.directory, $stage);
        $count
    }, :!wait)
}
#| Compare the selected database with the last applied snapshot. Ignore migration bookkeeping tables
#| and reject unexpected tables, column differences or missing indexes.
method verify(Str :$connection = 'default') {
    my $db = self!connection($connection);
    my $driver = self!dialect($db);
    my $*RED-DB = $db;
    my @history = self.history;
    my @states = self.status(:$connection);
    my $last = @states.grep(*.<state> eq 'applied').tail;
    my $snapshot = $last.defined
        ?? Red::Migration::Snapshot.load(@history.first(*.<id> eq $last<id>)<path>.add($driver).add('schema.rakuconf'))
        !! Red::Migration::Snapshot.new;
    my @actual = $db.schema-reader.tables-names.grep({ .defined && !($_ eq any(<red_migrations red_migration_files sqlite_sequence>)) }).sort;
    my @wanted = $snapshot.tables.map(*.name).sort;
    self!error('Database table set differs from the migration snapshot') unless @actual eqv @wanted;
    for $snapshot.tables -> $table {
        my $actual = $db.schema-reader.table-definition($table.name);
        self!error("Database schema differs from snapshot: {$table.name}") if $actual.diff($table).elems;
        for $table.indexes -> %index {
            self!error("Missing index {%index<name>}")
                unless $db.indexes-for-table($table.name).first(*.<name> eq %index<name>).defined;
        }
    }
    True
}
#| Rebase unpublished branches after a protected prefix in the requested tip order. Reject conflicts
#| and custom SQL, regenerate rewritten versions with new IDs, and validate before atomic
#| publication. Check every supplied deployment connection for already executed versions.
method serialize(Str :$after!, :@order = [], :@check-connections = []) {
    with-history-lock($!config.directory, {
        self!error('Prepare or remove drafts before serializing migration history')
            if self!entries.grep({ (.<state> // '') eq 'draft' });
        my @entries = self!entries;
        my %by-id = @entries.map({ .<id> => $_ });
        self!error("Unknown protected migration: $after") unless %by-id{$after}:exists;
        my @prefix;
        my $parent = '';
        until $parent eq $after {
            my @next = @entries.grep(*.<predecessor> eq $parent);
            self!error('Choose a shared linear prefix before the fork') unless @next.elems == 1;
            @prefix.push: @next[0]<id>;
            $parent = @next[0]<id>;
        }
        my %protected = set @prefix;
        my @suffix = @entries.grep({ !%protected{.<id>} });
        return 0 unless @suffix;
        my %parents = set @suffix.map(*.<predecessor>);
        my @heads = @suffix.grep({ !%parents{.<id>} }).map(*.<id>).sort;
        my @requested = @order ?? @order !! @heads;
        self!error('Order must name every branch head exactly once')
            unless @requested.sort eqv @heads.sort;
        my @sequence;
        my %seen;
        for @requested -> $head {
            my @chain;
            my %visiting;
            my $cursor = $head;
            until $cursor eq $after || %seen{$cursor} {
                self!error('Disconnected, missing or cyclic migration ancestry')
                    if %visiting{$cursor}++ || !(%by-id{$cursor}:exists) || %protected{$cursor};
                @chain.unshift($cursor);
                $cursor = %by-id{$cursor}<predecessor>;
            }
            for @chain -> $id { @sequence.push($id); %seen{$id} = True }
        }
        self!error('Disconnected or cyclic migration history') unless @sequence.elems == @suffix.elems;
        my %rewritten;
        my $proposed-parent = $after;
        for @sequence -> $id {
            if %by-id{$id}<predecessor> ne $proposed-parent {
                %rewritten{$id} = True;
                $proposed-parent = "rewritten:$id";
            } else { $proposed-parent = $id }
        }
        for @check-connections -> $connection {
            my $db = self!connection($connection);
            my $*RED-DB = $db;
            next unless 'red_migrations' eq any($db.schema-reader.tables-names.List);
            for Red::Migration::Applied.^all -> $row {
                self!error("Migration {$row.id} was already executed on $connection") if %rewritten{$row.id};
            }
        }
        for @suffix -> %migration {
            self!logical(%migration);
            self!error("Missing portable operations: {%migration<id>}")
                unless %migration<path>.add('operations.rakuconf').f;
            for %migration<drivers>.keys -> $driver {
                self!error("Custom SQL cannot be serialized automatically: {%migration<id>} ($driver)")
                    unless self!generated(%migration, $driver);
            }
        }
        my $stage = staging-history($!config.directory);
        LEAVE discard-staging-history($stage) if $stage.defined;
        my %state = schema-data(self!logical(%by-id{$after}));
        my $previous = $after;
        my $changed = 0;
        for @sequence -> $original-id {
            my %migration = %by-id{$original-id};
            my %before = schema-data(self!logical(%by-id{%migration<predecessor>}));
            my %target = schema-data(self!logical(%migration));
            my @operations = changes(%before, %target);
            my $stored = self!load(%migration<path>.add('operations.rakuconf'));
            self!error("Modified portable operations: $original-id") unless @operations eqv $stored.list.Array;
            my %merged = rebase(%state, @operations);
            if $previous eq %migration<predecessor> {
                $previous = $original-id;
                %state = %merged;
                next;
            }
            my $logical = schema-from-data(%merged);
            my $old = schema-from-data(%state);
            my $data = self!data-source(%migration);
            if $data.defined {
                my %aliases = (|Red::Migration::Snapshot.load(%migration<path>.add('before.rakuconf')).tables,
                    |self!logical(%migration).tables)
                    .map({ .name => .model-name });
                $logical = $logical.clone(:tables($logical.tables.map({
                    .clone(:model-name(%aliases{.name} // .model-name))
                }).Array));
                $old = $old.clone(:tables($old.tables.map({
                    .clone(:model-name(%aliases{.name} // .model-name))
                }).Array));
            }
            my $id = self!id;
            my $directory = $stage.add("$id-{%migration<name>}");
            $directory.mkdir;
            my %drivers;
            for %migration<drivers>.keys.sort -> $driver {
                %drivers{$driver} = self!variant($directory.add($driver), $old, $logical, $driver, :$data);
                if (%migration<drivers>{$driver}<down-state> // '') eq 'irreversible'
                        && %drivers{$driver}<down-state> eq 'pending' {
                    %drivers{$driver}<down-state> = 'irreversible';
                    %drivers{$driver}<down-reason> = %migration<drivers>{$driver}<down-reason>;
                } elsif (%drivers{$driver}<down-reason> // '').starts-with('Data transformations require')
                        && (%migration<drivers>{$driver}<down-state> // '') eq 'available'
                        && %migration<drivers>{$driver}<reversible> {
                    %drivers{$driver}<down-state> = 'available';
                    %drivers{$driver}<reversible> = True;
                    %drivers{$driver}<down-reason> = '';
                }
            }
            my $source = $logical.source;
            $directory.add('schema.rakuconf').spurt($source);
            $directory.add('operations.rakuconf').spurt(
                artifact-source('operations', changes(%state, %merged)));
            my %manifest = format => 2, :$id, name => %migration<name>, predecessor => $previous,
                replaces => $original-id, :%drivers, logical-checksum => self!checksum($source);
            if $data.defined {
                $directory.add('migration.raku').spurt($data);
                $directory.add('before.rakuconf').spurt($old.source);
                %manifest<data-checksum> = self!checksum($data);
                %manifest<before-checksum> = self!checksum($old.source);
                %manifest<state> = 'prepared';
            }
            $directory.add('migration.rakuconf').spurt(artifact-source('manifest', %manifest));
            remove-tree($stage.add(%migration<path>.basename));
            $previous = $id;
            %state = %merged;
            $changed++;
        }
        my $config = $!config.clone(:directory($stage));
        self.WHAT.new(:$config).test;
        publish-history($!config.directory, $stage) if $changed;
        $changed
    }, :!wait)
}
