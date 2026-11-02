use Red;
use UUID;
use Red::Type::Json;
use Red::Migration::Snapshot;
use X::Red::Migration;
=head2 Red::Migration::Logical

unit module Red::Migration::Logical;

#| Capture a portable model schema from concrete driver snapshots. Preserve Raku types, SQL type
#| origins and mappings, plus descriptors needed to regenerate indexes and constraints.
sub logical-capture(@models, %snapshots, @drivers --> Red::Migration::Snapshot) is export {
    my $first = %snapshots{@drivers[0]};
    my @tables = $first.tables.map: -> $table {
        my $model = @models.first(*.^table eq $table.name);
        my @columns = $table.columns.map: -> $column {
            my $original = $model.^columns.first(*.column.name eq $column.name).column;
            my $known = ::($column.raku-type);
            my %options = $original.attr.^can('args') ?? $original.attr.args !! {};
            my $explicit = (%options<type>:exists) || $known ~~ Failure
                || $original.attr.type.?red-type-column-type.DEFINITE;
            my %types;
            {
                for @drivers -> $driver {
                    %types{$driver} = %snapshots{$driver}.tables.first(*.name eq $table.name)
                        .columns.first(*.name eq $column.name).type;
                }
            }
            $column.clone(:type(''), :type-origin($explicit ?? 'explicit' !! 'derived'),
                :type-overrides(%types))
        };
        my @indexes = $model.^indexes.grep({ !.inline }).map({
            %(name => .name, source => .raku, driver => .driver)
        });
        my @checks = $model.^schema-constraints.map({
            %(name => .name, source => .raku, driver => .driver)
        });
        $table.clone(:@columns, :indexes[], :checks[],
            :portable-indexes(@indexes.Array), :portable-checks(@checks.Array),
            :primary-key($table.columns.grep(*.pk).map(*.name).Array))
    };
    Red::Migration::Snapshot.new(:@tables)
}

#| Reconstruct a trusted historical portable SQL descriptor without importing the current
#| application model implementation.
sub descriptor(Str $source) is export {
    use MONKEY-SEE-NO-EVAL;
    CATCH { default { X::Red::Migration.new(:reason("Cannot reconstruct a portable expression: {.message}")).throw } }
    EVAL $source
}

#| Resolve a portable snapshot into a concrete driver schema. Apply configured type mappings and
#| dialect-specific descriptors; reject explicit types without a mapping.
sub translate-logical(Red::Migration::Snapshot $logical, $backend, Str $dialect,
                      %mappings = {} --> Red::Migration::Snapshot) is export {
    my @tables = $logical.tables.map: -> $table {
        my @columns = $table.columns.map: -> $column {
            my $type;
            if $column.type-overrides{$dialect}:exists {
                $type = $column.type-overrides{$dialect};
            } elsif %mappings{"{$table.name}.{$column.name}"}:exists {
                $type = %mappings{"{$table.name}.{$column.name}"};
            } elsif %mappings{$column.raku-type}:exists { $type = %mappings{$column.raku-type} }
            elsif $column.type-origin eq 'explicit' {
                $type = $column.type-overrides{$dialect};
                X::Red::Migration.new(:reason("Provide a $dialect type mapping for {$table.name}.{$column.name}")).throw
                    unless $type.defined;
            } elsif $column.type-origin eq 'derived' {
                my $raku = ::($column.raku-type);
                X::Red::Migration.new(:reason("Unknown portable Raku type: {$column.raku-type}")).throw
                    if $raku ~~ Failure;
                $type = $column.auto-increment && $column.raku-type eq 'Mu'
                    ?? $backend.type-by-name('int') !! $backend.default-type-for-type($raku);
            } else {
                X::Red::Migration.new(:reason('Legacy snapshots need logical type-origin metadata before backfill')).throw;
            }
            $column.clone(:$type)
        };
        my @indexes;
        for $table.portable-indexes -> %definition {
            my $ast = descriptor(%definition<source>);
            next unless $backend.schema-definition-applies($ast);
            my $sql = $backend.translate($ast);
            X::Red::Migration.new(:reason('Portable index cannot contain SQL binds')).throw if $sql.value.elems;
            @indexes.push: %(name => %definition<name>, sql => $sql.key);
        }
        my @checks;
        for $table.portable-checks -> %definition {
            my $ast = descriptor(%definition<source>);
            next unless $backend.schema-definition-applies($ast);
            my $sql = $backend.translate($ast);
            X::Red::Migration.new(:reason('Portable constraint cannot contain SQL binds')).throw if $sql.value.elems;
            @checks.push: $sql.key;
        }
        $table.clone(:@columns, :indexes(@indexes.Array), :checks(@checks.Array))
    };
    Red::Migration::Snapshot.new(:@tables)
}

#| Convert a snapshot into canonical nested data for schema comparison and branch rebasing. Exclude
#| model names from structural conflict detection.
sub schema-data(Red::Migration::Snapshot $snapshot --> Hash) is export {
    my %tables;
    for $snapshot.tables -> $table {
        my %columns;
        for $table.columns -> $column {
            %columns{$column.name} = %(name => $column.name, raku-type => $column.raku-type,
                type => $column.type, type-origin => $column.type-origin,
                type-overrides => $column.type-overrides.Hash,
                nullable => $column.nullable, pk => $column.pk, unique => $column.unique,
                auto-increment => $column.auto-increment, references => $column.references.Hash);
        }
        %tables{$table.name} = %(name => $table.name,
            :%columns, constraints => $table.constraints.list.Array, primary-key => $table.primary-key.list.Array,
            portable-indexes => $table.portable-indexes.list.Array, portable-checks => $table.portable-checks.list.Array);
    }
    %( :%tables )
}

#| Rebuild a logical snapshot from canonical schema data after changes have been merged or rebased.
sub schema-from-data(%data --> Red::Migration::Snapshot) is export {
    my @tables = %data<tables>.keys.sort.map: -> $name {
        my %table = %data<tables>{$name};
        my @columns = %table<columns>.keys.sort.map({ Red::Cli::Column.new(|%table<columns>{$_}) });
        %table<columns>:delete;
        my @primary = (%table<primary-key>:delete).list;
        my @constraints = (%table<constraints>:delete).list;
        my @indexes = (%table<portable-indexes>:delete).list;
        my @checks = (%table<portable-checks>:delete).list;
        Red::Cli::Table.new(|%table, :@columns, :primary-key(@primary.List),
            :constraints(@constraints.List), :portable-indexes(@indexes.List),
            :portable-checks(@checks.List))
    };
    Red::Migration::Snapshot.new(:@tables)
}

#| Return deterministic path-based differences between canonical schemas, retaining old and new
#| values so conflicts can be checked during rebasing.
sub changes(%before, %after, :@path = [] --> Array) is export {
    my @changes;
    for (|%before.keys, |%after.keys).unique.sort -> $key {
        my @next = |@path, $key;
        if (%before{$key}:exists) && (%after{$key}:exists)
                && %before{$key} ~~ Hash && %after{$key} ~~ Hash {
            @changes.append: changes(%before{$key}, %after{$key}, :path(@next));
        } elsif !(%before{$key}:exists) || !(%after{$key}:exists)
                || !(%before{$key} eqv %after{$key}) {
            @changes.push: %(path => @next.Array, had => (%before{$key}:exists),
                has => (%after{$key}:exists), before => %before{$key}, after => %after{$key});
        }
    }
    @changes.Array
}

#| Recursively copy canonical schema collections before applying changes, leaving the original state
#| unchanged.
sub clone-data($value) {
    given $value {
        when Hash { .pairs.map({ .key => clone-data(.value) }).Hash }
        when Positional { .list.map({ clone-data($_) }).Array }
        default { $_ }
    }
}

#| Apply recorded schema changes to an accumulated branch state. Accept already equivalent changes
#| and reject paths whose original value no longer matches.
sub rebase(%state, @changes --> Hash) is export {
    my %result = clone-data(%state);
    for @changes -> %change {
        my @path = %change<path>.List;
        my $key = @path.pop;
        my $container := %result;
        for @path -> $part {
            X::Red::Migration.new(:reason("Serialization conflict at {%change<path>.join('.')}")).throw
                unless $container{$part}:exists;
            $container := $container{$part};
        }
        my $present = $container{$key}:exists;
        next if $present == %change<has> && (!$present || $container{$key} eqv %change<after>);
        X::Red::Migration.new(:reason("Serialization conflict at {%change<path>.join('.')}")).throw
            unless $present == %change<had> && (!$present || $container{$key} eqv %change<before>);
        if %change<has> { $container{$key} = %change<after> }
        else { $container{$key}:delete }
    }
    %result
}
