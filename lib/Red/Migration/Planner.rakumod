use Red;
use Red::Migration::Snapshot;
use X::Red::Migration;
=head2 Red::Migration::Planner

unit class Red::Migration::Planner;

has $.driver is required;
has Str $.dialect is required;

#| Raise a typed error explaining why a schema operation cannot be generated safely.
method !error(Str $reason) { X::Red::Migration.new(:$reason).throw }
#| Quote a SQL identifier using the selected backend conventions.
method !q(Str $name) { $!driver.table-name-wrapper($name) }

#| Capture configured model schemas, indexes and constraints for this dialect. Reject unsupported
#| model kinds, defaults and reserved bookkeeping table names.
method capture(@models --> Red::Migration::Snapshot) {
    my $*RED-DB = $!driver;
    my @tables = @models.map: -> $model {
        self!error("Views and temporary tables require an explicit migration: {$model.^name}")
            if $model.^temp || $model.HOW.^name.contains('View');
        self!error("Column defaults require an explicit SQL migration: {$model.^name}")
            if $model.^columns.grep({ .column.default.defined }).elems;
        my $table = $model.^describe;
        self!error("{$table.name} is reserved for migration history")
            if $table.name eq any(<red_migrations red_migration_files>);
        self!error("Duplicate column names in {$table.name}")
            unless $table.columns.map(*.name).unique.elems == $table.columns.elems;
        my @indexes = $model.^indexes.grep({ !.inline && $!driver.schema-definition-applies($_) }).map: -> $index {
            my $translated = $!driver.translate($index);
            my $sql = $translated.key;
            my @bind = $translated.value.List;
            self!error('Index DDL cannot contain bind parameters') if @bind;
            %(name => $index.name, sql => $sql)
        };
        my @checks = $model.^schema-constraints.grep({ $!driver.schema-definition-applies($_) }).map: {
            my $translated = $!driver.translate($_);
            my $sql = $translated.key;
            my @bind = $translated.value.List;
            self!error('Constraint DDL cannot contain bind parameters') if @bind;
            $sql
        };
        $table.clone(:indexes(@indexes.sort(*.<name>).Array), :checks(@checks.sort.Array),
            :constraints($table.constraints.sort(*.join('|')).Array))
    };
    self!error('Duplicate table names in migration configuration')
        unless @tables.map(*.name).unique.elems == @tables.elems;
    Red::Migration::Snapshot.new(:@tables)
}

#| Render a column definition with its nullability, uniqueness and supported automatic-primary-key
#| syntax for this dialect.
method !column($col, Bool :$single-pk = False --> Str) {
    my $type = $col.type;
    my $extra = '';
    if $col.auto-increment {
        self!error('Automatic IDs must be a single integer primary key')
            unless $single-pk && $col.pk && $type.lc ~~ /int|serial/;
        given $!dialect {
            when 'SQLite' { $type = 'INTEGER'; $extra = ' PRIMARY KEY AUTOINCREMENT' }
            when 'Pg' { $type = $type.lc.contains('big') ?? 'BIGSERIAL' !! 'SERIAL'; $extra = ' PRIMARY KEY' }
            when 'MySQL' { $extra = ' PRIMARY KEY AUTO_INCREMENT' }
        }
    } elsif $single-pk && $col.pk { $extra = ' PRIMARY KEY' }
    self!q($col.name) ~ " $type" ~ ($col.nullable ?? '' !! ' NOT NULL') ~ $extra
        ~ ($col.unique ?? ' UNIQUE' !! '')
}

#| Render CREATE TABLE from a captured table, including supported primary keys, unique groups,
#| references and checks.
method !create($table --> Str) {
    my @pk = $table.primary-key
        ?? $table.primary-key.map(-> $name { $table.columns.first(*.name eq $name) })
        !! $table.columns.grep(*.pk);
    my @defs = $table.columns.map({ self!column($_, :single-pk(@pk.elems == 1)) });
    @defs.push('PRIMARY KEY (' ~ @pk.map({ self!q(.name) }).join(', ') ~ ')') if @pk > 1;
    for $table.constraints.grep(*.elems > 1) -> @cols {
        @defs.push('UNIQUE (' ~ @cols.map({ self!q($_) }).join(', ') ~ ')');
    }
    for $table.columns.grep({ .references<table>.defined }) -> $col {
        @defs.push('FOREIGN KEY (' ~ self!q($col.name) ~ ') REFERENCES '
            ~ self!q($col.references<table>) ~ ' (' ~ self!q($col.references<column>) ~ ')');
    }
    @defs.append($table.checks);
    'CREATE TABLE ' ~ self!q($table.name) ~ " (\n    " ~ @defs.join(",\n    ") ~ "\n)"
}

#| Return ordered SQL statements that transform one snapshot into another. Create referenced tables
#| first, require explicit destructive permission for removals, and reject unsupported conversions
#| or constraint alterations.
method diff(Red::Migration::Snapshot $old, Red::Migration::Snapshot $new,
            Bool :$allow-destructive = False --> Array) {
    my %old = $old.tables.map({ .name => $_ });
    my %new = $new.tables.map({ .name => $_ });
    for $new.tables -> $table {
        for $table.columns.grep({ .references<table>.defined }) -> $column {
            my $parent = %new{$column.references<table>};
            self!error("Missing referenced table {$column.references<table>}") unless $parent.defined;
            my $key = $parent.columns.first(*.name eq $column.references<column>);
            self!error("Foreign keys require an individually unique target: {$table.name}.{$column.name}")
                unless $key.defined && ($key.unique || ($key.pk && $parent.columns.grep(*.pk).elems == 1));
        }
    }
    my @sql;
    my @create = %new.keys.grep({ !(%old{$_}:exists) }).sort;
    my %done = %old;
    while @create {
        my $table = @create.first: -> $name {
            %new{$name}.columns.grep({ .references<table>.defined }).grep({
                .references<table> ne $name && !(%done{.references<table>}:exists)
            }).elems == 0
        };
        # Avoid junction truthiness and provide an explicit cycle/missing-parent error.
        unless $table.defined {
            self!error('New tables contain a dependency cycle or reference an absent table');
        }
        @sql.push: self!create(%new{$table});
        @sql.append: %new{$table}.indexes.map(*.<sql>);
        %done{$table} = %new{$table};
        @create = @create.grep(* ne $table);
    }
    for %new.keys.grep({ %old{$_}:exists }).sort -> $name {
        my $a = %old{$name}; my $b = %new{$name};
        self!error("Constraint changes require an explicit migration: $name")
            unless $a.constraints.raku eq $b.constraints.raku && $a.checks.raku eq $b.checks.raku;
        my %ac = $a.columns.map({ .name => $_ });
        my %bc = $b.columns.map({ .name => $_ });
        for %bc.keys.sort -> $column {
            my $col = %bc{$column};
            if !(%ac{$column}:exists) {
                self!error("Only nullable unconstrained additions are automatic: $name.$column")
                    if !$col.nullable || $col.pk || $col.unique || $col.auto-increment || $col.references<table>.defined;
                @sql.push: 'ALTER TABLE ' ~ self!q($name) ~ ' ADD COLUMN ' ~ self!column($col);
            } elsif %ac{$column}.diff($col).elems
                    || %ac{$column}.auto-increment != $col.auto-increment {
                my $before = %ac{$column};
                self!error("Constrained column alteration requires an explicit migration: $name.$column")
                    if $a.indexes.elems || $col.pk || $before.pk || $col.unique || $before.unique
                        || $col.auto-increment || $before.auto-increment
                        || $col.references<table>.defined || $before.references<table>.defined;
                self!error("SQLite table reconstruction is not implemented: $name.$column") if $!dialect eq 'SQLite';
                if $before.type.lc ne $col.type.lc {
                    my $x = $before.type.lc.match(/^ 'varchar(' (\d+) ')' $/);
                    my $y = $col.type.lc.match(/^ 'varchar(' (\d+) ')' $/);
                    self!error("Only VARCHAR widening is automatic: $name.$column; provide explicit SQL for type conversions")
                        unless $x && $y && +$y[0] >= +$x[0];
                }
                my $prefix = 'ALTER TABLE ' ~ self!q($name);
                if $!dialect eq 'MySQL' {
                    @sql.push: "$prefix MODIFY COLUMN " ~ self!column($col);
                } else {
                    @sql.push: "$prefix ALTER COLUMN " ~ self!q($column) ~ ' TYPE ' ~ $col.type
                        if $before.type ne $col.type;
                    @sql.push: "$prefix ALTER COLUMN " ~ self!q($column)
                        ~ ($col.nullable ?? ' DROP NOT NULL' !! ' SET NOT NULL')
                        if $before.nullable != $col.nullable;
                }
            }
        }
        for %ac.keys.grep({ !(%bc{$_}:exists) }).sort -> $column {
            self!error("Removing $name.$column requires --allow-destructive") unless $allow-destructive;
            my $col = %ac{$column};
            self!error("Constrained column removal requires an explicit migration: $name.$column")
                if $col.pk || $col.unique || $col.references<table>.defined
                    || $a.indexes.elems;
            self!error("Referenced column removal requires an explicit migration: $name.$column")
                if $old.tables.map(*.columns).flat.grep({
                    (.references<table> // '') eq $name && (.references<column> // '') eq $column
                });
            @sql.push: 'ALTER TABLE ' ~ self!q($name) ~ ' DROP COLUMN ' ~ self!q($column);
        }
        my %ai = $a.indexes.map({ .<name> => .<sql> });
        my %bi = $b.indexes.map({ .<name> => .<sql> });
        for %ai.keys.sort -> $index {
            next if (%bi{$index}:exists) && %bi{$index} eq %ai{$index};
            @sql.push: 'DROP INDEX ' ~ self!q($index)
                ~ ($!dialect eq 'MySQL' ?? ' ON ' ~ self!q($name) !! '');
        }
        for %bi.keys.sort -> $index {
            @sql.push: %bi{$index} unless (%ai{$index}:exists) && %ai{$index} eq %bi{$index};
        }
    }
    my @drop = %old.keys.grep({ !(%new{$_}:exists) }).sort;
    self!error('Removing tables requires --allow-destructive') if @drop && !$allow-destructive;
    while @drop {
        my $name = @drop.first: -> $candidate {
            $old.tables.grep({ .name ne $candidate && (%done{.name}:exists) }).grep({
                .columns.grep({ (.references<table> // '') eq $candidate }).elems
            }).elems == 0
        };
        self!error('Table removal has dependent tables; use an explicit migration') unless $name.defined;
        @sql.push: 'DROP TABLE ' ~ self!q($name);
        %done{$name}:delete;
        @drop = @drop.grep(* ne $name);
    }
    @sql.Array
}
