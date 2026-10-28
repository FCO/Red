use Red::Do;
use Red::DB;
use X::Red::Exceptions;
use Red::AST::CreateTableCli;
use Red::Driver::Pg;
unit class Red::Schema;

proto sub schema(|) { * }

multi sub schema(+@models) is export {
    ::?CLASS.new: @models
}

multi sub schema(*%models) is export {
    ::?CLASS.new: %models
}

has %.models;

multi method new(@models) {
    my %models = @models.map: {
        do if $_ ~~ Str {
            require ::($_);
            $_ => ::($_)
        } else {
            .^name => $_
        }
    }
    self.bless: :%models
}

multi method new(%model-alias) {
    my %models = %model-alias.kv.map: -> $alias, $model {
        do if $model ~~ Str {
            require ::($model);
            $alias => ::($model)
        } else {
            $alias => $model
        }
    }
    self.bless: :%models
}


method FALLBACK(Str $name) {
    $.model($name);
}

method model(Str $name) {
    do if %!models{ $name }:exists {
        %!models{ $name }
    } else {
        fail "Model '$name' not found on schema"
    }
}

# TODO: For tests only, please make it right
method drop {
    for %!models.values {
        my $drop = "DROP TABLE IF EXISTS { get-RED-DB.table-name-wrapper: .^table } { "CASCADE" if get-RED-DB.should-drop-cascade }";
        get-RED-DB.execute($drop);
        #.emit: $drop
    }
    self
}

method create(:$where) {
    red-do (:$where with $where), :transaction, {
        |.create-schema(%!models);
    }
    self
}

method plan(:$where --> Array[Str]()) {
    my $driver = $where // get-RED-DB;
    {
        my $*RED-DB = $driver;
        self!render-plan($driver, self.diff-from-db)
    }
}

method !render-plan($driver, @changes --> Array[Str]()) {
    {
        my $*RED-DB = $driver;
        my @sql;
        sub unsupported(Str $reason) {
            X::Red::Schema::UnsupportedChange.new(:$reason).throw;
        }
        my &quote = -> $name { $driver.table-name-wrapper($name) };
        my %targets = %!models.values.map({ .^table => .^describe });
        my @pending = @changes.grep({ .[1] eq '+' && .[2] eq 'table' });
        my %creating = @pending.map({ .[3].name => True });
        for @pending -> @change {
            for @change[3].columns.grep({ .references<table>.defined }) -> $column {
                my $reference = $column.references;
                my $parent = %targets{$reference<table>}
                    // $driver.schema-reader.table-definition($reference<table>);
                unsupported("missing referenced table {$reference<table>}")
                    unless $parent.DEFINITE && $parent.exists;
                my $key = $parent.columns.first(*.name eq $reference<column>);
                unsupported("referenced column must be an individual primary/unique key: {$reference<table>}.{$reference<column>}")
                    unless $key.DEFINITE && ($key.unique
                        || ($key.pk && $parent.columns.grep(*.pk).elems == 1));
            }
        }
        while @pending {
            my $position = @pending.first(-> @change {
                !@change[3].columns.grep({
                    .references<table>.defined && .references<table> ne @change[3].name
                        && (%creating{.references<table>}:exists)
                }).elems
            }, :k);
            unsupported('cyclic foreign keys between new tables') unless $position.defined;
            my $change = @pending.splice($position, 1).head;
            @sql.append: $driver.translate(Red::AST::CreateTableCli.new(:table($change[3]))).map(*.key);
            %creating{$change[3].name}:delete;
        }
        for @changes -> @change {
            next if @change[1] eq '+' && @change[2] eq 'table';
            my $table = @change[0];
            my $name = @change[1];
            if $name eq '+' && @change[2] eq 'col' {
                my $column = @change[3];
                unsupported("adding constrained/non-null column {$table}.{$column.name}")
                    unless $column.nullable && !$column.pk && !$column.unique
                        && !$column.references<table>.defined;
                @sql.push: "ALTER TABLE {quote($table)} ADD COLUMN "
                    ~ $driver.translate($column, 'create-table').key;
            } elsif $name eq '-' && @change[2] eq 'col' {
                my $column = @change[3];
                unsupported("removing constrained column {$table}.{$column.name}")
                    if $column.pk || $column.unique || $column.references<table>.defined;
                my @dependencies = $driver.schema-reader.?column-dependencies($table, $column.name).list;
                unsupported("dependencies prevent removing {$table}.{$column.name}")
                    if @dependencies.grep(*.defined).elems;
                if $driver.driver-name.contains('SQLite') {
                    my $version = $driver.execute('SELECT sqlite_version() AS version').row<version>;
                    unsupported('DROP COLUMN requires SQLite 3.35 or newer') if Version.new($version) < v3.35;
                }
                @sql.push: "ALTER TABLE {quote($table)} DROP COLUMN {quote($column.name)}";
            } elsif @change.elems == 5 && @change[2] eq '-' {
                next;
            } elsif @change.elems == 5 && @change[2] eq '+' {
                my $kind = @change[3];
                unsupported("$kind on {$table}.{$name} is not implemented by SQLite schema sync in this phase")
                    if $driver.driver-name.contains('SQLite');
                my $column = %targets{$table}.columns.first(*.name eq $name);
                my $old = $driver.schema-reader.table-definition($table).columns.first(*.name eq $name);
                unsupported("changing constrained column {$table}.{$name}")
                    if $column.pk || $column.unique || $column.references<table>.defined;
                if $kind eq 'nullable' && !$column.nullable {
                    my $statement = $driver.execute("SELECT COUNT(*) AS red_count FROM {quote($table)} WHERE {quote($name)} IS NULL");
                    unsupported("NULL data prevents NOT NULL on {$table}.{$name}")
                        if $statement.row<red_count> > 0;
                }
                if $kind eq 'type' {
                    my $from = $old.type.lc.subst('character varying', 'varchar');
                    my $to = $column.type.lc.subst('character varying', 'varchar');
                    my $old-match = $from ~~ /^ 'varchar(' (\d+) ')' $/;
                    my $new-match = $to ~~ /^ 'varchar(' (\d+) ')' $/;
                    unsupported("only VARCHAR widening is supported: {$table}.{$name} ($from -> $to)")
                        unless $old-match && $new-match && +$new-match[0] >= +$old-match[0];
                } elsif $kind ne 'nullable' {
                    unsupported("changing $kind on {$table}.{$name}");
                }
                if $driver.driver-name.contains('MySQL') {
                    # Full column metadata is required to avoid losing unmanaged defaults or attributes.
                    my $statement = $driver.execute('SELECT COLUMN_DEFAULT AS d, EXTRA AS e, COLUMN_COMMENT AS comment, CHARACTER_SET_NAME AS charset, COLLATION_NAME AS collation FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=? AND COLUMN_NAME=?', $table, $name);
                    my $metadata = $statement.row;
                    unsupported("unmanaged default or attributes on {$table}.{$name}")
                        if $metadata<d>.defined || ($metadata<e> // '').chars
                            || ($metadata<comment> // '').chars || $column.auto-increment;
                    if $metadata<charset>.defined && $metadata<collation>.defined {
                        $column = $column.clone(:type($column.type ~ " CHARACTER SET {$metadata<charset>} COLLATE {$metadata<collation>}"));
                    }
                    @sql.push: "ALTER TABLE {quote($table)} MODIFY COLUMN "
                        ~ $driver.translate($column, 'create-table').key;
                } else {
                    @sql.push: "ALTER TABLE {quote($table)} ALTER COLUMN {quote($name)} "
                        ~ ($kind eq 'type' ?? "TYPE {$column.type}"
                            !! ($column.nullable ?? 'DROP NOT NULL' !! 'SET NOT NULL'));
                }
            } else {
                unsupported("unimplemented difference {@change.raku}");
            }
        }
        @sql.unique.Array
    }
}

method update(:$where, Bool :$allow-destructive = False) {
    my $driver = $where // get-RED-DB;
    {
        my $*RED-DB = $driver;
        my @diff = self.diff-from-db;
        unless $allow-destructive {
            for @diff -> @change {
                if @change[1] eq '-' && @change[2] eq any(<col table>) {
                    X::Red::Schema::DestructiveChange.new(:table(@change[0])).throw;
                }
            }
        }
        # Translate the complete plan before opening a transaction or executing DDL.
        my @sql = self!render-plan($driver, @diff);
        return self unless @sql;
        $driver.execute('PRAGMA foreign_keys = ON') if $driver.driver-name.contains('SQLite');
        my Bool $transactional = !$driver.driver-name.contains('MySQL');
        my $transaction = $transactional ?? $driver.begin !! $driver;
        my @completed;
        my Str $current = '';
        {
            CATCH {
                default {
                    my $cause = $_;
                    try $transaction.rollback if $transactional;
                    X::Red::Schema::UpdateFailed.new(:sql($current),
                        :completed-statements(@completed), :$cause).throw;
                }
            }
            for @sql -> $sql {
                $current = $sql;
                $transaction.execute($sql);
                @completed.push: $sql;
            }
            if $transactional {
                $current = 'COMMIT';
                $transaction.commit;
            }
        }
    }
    self
}

method diff-from-db {
    [
        |do for %!models.values.sort(*.^table) -> $model {
            next unless $model ~~ Red::Model;
            |($model.^diff-from-db // [])
        }
    ]
}

method diff-to-db {
    [
        |do for %!models.values.sort(*.^table) -> $model {
            next unless $model ~~ Red::Model;
            |($model.^diff-to-db // [])
        }
    ]
}
