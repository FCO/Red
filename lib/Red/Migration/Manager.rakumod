use Red;
use Red::Migration::Configuration;
use Red::Migration::Snapshot;
use Red::Migration::Planner;
use Red::Migration::Applied;
use Red::Migration::Resolution;
use Red::Migration::File;
use Red::Migration::SQL;
use Red::Migration::Scripts;
use Red::Migration::Environment;
use Red::Migration::Logical;
use Red::Migration::Storage;
use Red::Migration::Artifact;
use Red::Migration::Data;
use Red::Migration::Dependencies;
use Red::Migration::Import;
use X::Red::Migration;
use UUID;
use JSON::Fast;
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

#| Publish prepared artifacts as resources without regenerating their contents.
method bundle(IO() :$project = '.') {
    CATCH {
        when X::Red::Migration { .rethrow }
        default { self!error("Cannot publish migration bundle: {.message}") }
    }
    with-history-lock($!config.directory, {
        with-bundle-lock($project, {
        self!error('Prepare or remove drafts before bundling')
            if self!entries.grep({ (.<state> // '') eq 'draft' });
        my @history = self!history;
        my $meta-file = $project.add('META6.json');
        self!error("Missing distribution metadata: $meta-file") unless $meta-file.f;
        my %meta = from-json($meta-file.slurp);
        my $root = $project.add('resources/red/migrations');
        my $stage = $project.add('resources/.red-migrations-' ~ UUID.new.Str);
        LEAVE remove-tree($stage) if $stage.defined && $stage.e;
        my %managed = 'red/migrations/index.json' => True;
        if $root.d {
            copy-tree($root, $stage);
            my $old-index = $root.add('index.json');
            if $old-index.f {
                my %old-index = from-json($old-index.slurp);
                sub inventory($value) {
                    if $value ~~ Associative {
                        if $value<path> ~~ Str && $value<path>.starts-with('red/migrations/') {
                            my $relative = $value<path>.substr('red/migrations/'.chars);
                            self!error('Invalid resource path in previous bundle')
                                if $relative.split('/').grep({ $_ eq any('', '.', '..') })
                                    || $relative.contains('\\');
                            %managed{$value<path>} = True;
                        }
                        inventory($_) for $value.values;
                    } elsif $value ~~ Positional { inventory($_) for $value.list }
                }
                for (%old-index<migrations> // []).list -> $entry {
                    inventory($entry<files> // {});
                    inventory($entry<drivers> // {});
                }
            }
            for %managed.keys -> $resource {
                my $file = $stage.add($resource.substr('red/migrations/'.chars));
                self!error("Expected a managed resource file: $resource") if $file.e && !$file.f;
                $file.unlink if $file.f;
            }
        } else { make-directory($stage) }
        my @entries;
        my %previous;
        my $previous-id = '';
        my %requirements;
        my %dependency-state = import-state($!config.directory);
        my $has-adopted = False;
        my %positions = @history.kv.map(-> $index, $entry { $entry<id> => $index });
        my %adoption-position;
        for (%dependency-state<adoptions> // {}).kv -> $identity, $adoption {
            %adoption-position{$identity} = $adoption<versions>.values.map({
                %positions{.<anchor>} // -1
            }).max;
        }
        my %table-origins;
        my @resources = 'red/migrations/index.json';
        for @history -> %migration {
            my $adopted = %migration<imported>
                && so %dependency-state<adopted>{%migration<origin><identity>};
            if %migration<imported> && !$adopted {
                %requirements{%migration<origin><identity>} = %migration<id>;
                next;
            }
            $has-adopted ||= $adopted;
            self!error('Migration directory symlinks are unsupported') if %migration<path>.l;
            my $id = %migration<id>;
            my %files;
            sub publishable(IO::Path $file --> Bool) {
                (!$file.basename.starts-with('.') || $file.basename eq '.origin')
                    && !$file.basename.ends-with('.lock')
                    && !$file.basename.ends-with('.journal.json')
            }
            sub copy-artifact(IO::Path $source, Str $relative) {
                self!error("Migration symlinks are unsupported: $source") if $source.l;
                if $source.d {
                    copy-artifact($_, "$relative/{.basename}") for $source.dir.grep(&publishable).sort(*.basename);
                } else {
                    my $target = $stage.add("$id/$relative");
                    make-directory($target.parent);
                    self!error("Resource already exists outside the previous bundle: $target")
                        if $target.e;
                    $source.copy($target);
                    my $resource = "red/migrations/$id/$relative";
                    my $text = try $source.slurp;
                    my $binary = !$text.defined;
                    my $fingerprint = $binary ?? $source.slurp(:bin).decode('iso-8859-1') !! $text;
                    %files{$relative} = %(path => $resource,
                        checksum => self!checksum($fingerprint), :$binary);
                    @resources.push($resource);
                }
            }
            for %migration<path>.dir.grep(&publishable).sort(*.basename) -> $file {
                copy-artifact($file, $file.basename);
            }
            if $adopted {
                my $adoption = %dependency-state<adoptions>{%migration<origin><identity>};
                my $baseline = $adoption<versions>{$id}<path>;
                if $baseline.defined && $baseline ne %migration<path>.basename {
                    my $archive = $!config.directory.add($baseline);
                    for $archive.dir.grep(&publishable).sort(*.basename) -> $file {
                        copy-artifact($file, "adopt-baseline/{$file.basename}");
                    }
                }
            }
            my %drivers;
            for %migration<drivers>.keys -> $driver {
                for <up down> -> $direction {
                    my %script = read-direction(%migration<path>.add($driver), $direction, $driver);
                    %drivers{$driver}{$direction} = %script<files>.map({
                        %( |%files{"$driver/{.<file>}"}, name => .<file> )
                    }).Array;
                }
            }
            my %current;
            if $adopted {
                %current = %previous;
                my %changes = %migration<origin><tables> // {};
                for (%changes<create> // []).list -> $table {
                    %current{$table} = True;
                    %table-origins{$table} = %migration<origin><identity>;
                }
                for (%changes<rename> // {}).kv -> $old, $new {
                    %current{$old}:delete;
                    %current{$new} = True;
                    %table-origins{$new} = %table-origins{$old}:delete;
                }
                %current{$_}:delete for (%changes<drop> // []).list;
            } else {
                %current = self!logical(%migration).tables.map({ .name => True });
                for %previous.keys -> $table {
                    my $origin = %table-origins{$table};
                    %current{$table} = True if $origin.defined
                        && %positions{$id} <= (%adoption-position{$origin} // -1);
                }
            }
            my %manifest = %migration;
            %manifest<path>:delete;
            @entries.push: %(id => $id, name => %migration<name>,
                predecessor => $previous-id, manifest => %manifest,
                requires => %requirements.keys.sort.map({
                    %(identity => $_, id => %requirements{$_})
                }).Array,
                files => %files, drivers => %drivers,
                tables => %(create => %current.keys.grep({ !(%previous{$_}:exists) }).sort.Array,
                    drop => %previous.keys.grep({ !(%current{$_}:exists) }).sort.Array));
            %previous = %current;
            $previous-id = $id;
        }
        # Once ownership has transferred, its original SQL must travel with our distribution.
        # Publish a composed final baseline alongside (not over) the original artifacts.
        if $has-adopted && @entries {
            my $entry = @entries.tail;
            for ('logical', |$!config.drivers) -> $driver {
                my $snapshot = $driver eq 'logical'
                    ?? self!local-snapshot(@history)
                    !! self!local-snapshot(@history, :$driver);
                my $namespace = nqp::sha1(%meta<name> ~ ':auth<' ~ (%meta<auth> // '') ~ '>');
                my $name = "bundle-baseline/$namespace/$driver.rakuconf";
                my $file = $stage.add("{$entry<id>}/$name");
                make-directory($file.parent);
                $file.spurt($snapshot.source);
                my $resource = "red/migrations/{$entry<id>}/$name";
                $entry<files>{$name} = %(path => $resource,
                    checksum => self!checksum($file.slurp), binary => False);
                $entry<baseline>{$driver} = $name;
                @resources.push($resource);
            }
        }
        $stage.add('index.json').spurt(to-json(%(format => 2, migrations => @entries.Array), :sorted-keys));
        my @old = (%meta<resources> // []).list;
        %meta<resources> = (|@old.grep({ !%managed{$_} }), |@resources).unique.sort.Array;
        my $meta-stage = $meta-file.parent.add('.META6-migrations-' ~ UUID.new.Str);
        LEAVE $meta-stage.unlink if $meta-stage.defined && $meta-stage.e;
        $meta-stage.spurt(to-json(%meta, :sorted-keys));
        publish-bundle($project, $stage, $meta-stage);
        @entries.elems
        });
    }, :!wait)
}

#| Import immutable SQL bundles from the installed runtime dependencies, without a database.
method import(IO() :$project = '.', :@bundles) {
    with-history-lock($!config.directory, {
        self!error('Prepare or remove migration drafts before importing')
            if self!entries.grep({ (.<state> // '') eq 'draft' });
        my @sources = @bundles ?? @bundles !! discover-bundles($project);
        my @history = self!history;
        my %state = import-state($!config.directory);
        my %owned = %state<tables>;
        my %local-tables;
        my @local = @history.grep({ !.<imported> });
        if @local { %local-tables = self!logical(@local.tail).tables.map({ .name => True }) }
        # Imported/adopted snapshots are executable artifacts: use the ownership registry
        # for conflict checks, never evaluate them while copying another dependency.
        my %positions = @history.kv.map(-> $index, $entry { $entry<id> => $index });
        my $local-position = @local ?? %positions{@local.tail<id>} !! -1;
        for (%state<adoptions> // {}).values -> $adoption {
            my @anchors = $adoption<versions>.values.grep({ %positions{.<anchor>}:exists });
            next unless @anchors;
            my $anchor = @anchors.map({ %positions{.<anchor>} }).max;
            if $anchor >= $local-position {
                %local-tables{$_} = True for $adoption<tables>.list;
            }
        }
        %local-tables{$_} = True for (%state<baselines> // {}).keys;
        my %records = %state<records>;
        for @sources -> $bundle {
            for $bundle.migrations -> $migration {
                next if %records{$migration<id>}:exists;
                my @introduced = (|($migration<tables><create> // []).list,
                    |($migration<tables><rename> // {}).values);
                for @introduced -> $table {
                    self!error("Table already managed locally: $table")
                        if !(%owned{$table}:exists)
                            && (%local-tables{$table}:exists);
                }
            }
        }
        import-bundles($!config.directory, @history, @sources, $!config.drivers)
    }, :!wait)
}

method !external-tables(--> Array) {
    import-state($!config.directory)<tables>.keys.Array
}

method !models(--> Array) {
    my @external = self!external-tables;
    $!config.model-types.grep({ !(.^table eq any(@external)) }).Array
}

# Local snapshots deliberately exclude schemas owned by dependencies.
method !local-snapshot(@history, Str :$driver) {
    my @local = @history.grep({ !.<imported> });
    if @local && $driver.defined {
        my $file = @local.tail<path>.add($driver).add('schema.rakuconf');
        self!error("Modified snapshot: $file") unless $file.f && self!checksum($file.slurp)
            eq @local.tail<drivers>{$driver}<snapshot-checksum>;
    }
    my $snapshot = @local
        ?? ($driver.defined
            ?? Red::Migration::Snapshot.load(@local.tail<path>.add($driver).add('schema.rakuconf'))
            !! self!logical(@local.tail))
        !! Red::Migration::Snapshot.new;
    my $adopted = $!config.directory.add('.adopt-' ~ ($driver // 'logical') ~ '.rakuconf');
    if $adopted.f {
        my %baseline = import-state($!config.directory)<baselines> // {};
        my @all = @history;
        my %positions = @all.kv.map(-> $index, $entry { $entry<id> => $index });
        my $local-position = @local ?? %positions{@local.tail<id>} !! -1;
        my %tables = Red::Migration::Snapshot.load($adopted).tables.grep({
            my $anchor = %baseline{.name} // '';
            my $anchor-position = $anchor.chars ?? (%positions{$anchor} // -1) !! -1;
            (%baseline{.name}:exists) && $local-position <= $anchor-position
                && (!$anchor.chars || @history.grep(*.<id> eq $anchor).elems)
        }).map({ .name => $_ });
        %tables{.name} = $_ for $snapshot.tables;
        $snapshot = Red::Migration::Snapshot.new(:tables(%tables.values.sort(*.name).Array));
    }
    my %state = import-state($!config.directory);
    my %positions = @history.kv.map(-> $index, $entry { $entry<id> => $index });
    my $local-position = @local ?? %positions{@local.tail<id>} !! -1;
    my %merged = $snapshot.tables.map({ .name => $_ });
    for (%state<adoptions> // {}).values -> $adoption {
        my @versions = $adoption<versions>.values.grep({ %positions{.<anchor>}:exists })
            .sort({ %positions{.<anchor>} });
        next unless @versions;
        my $version = @versions.tail;
        next if %positions{$version<anchor>} < $local-position;
        my $key = $driver // 'logical';
        my $name = $version<names>{$key}
            // ($driver.defined ?? "$driver/schema.rakuconf" !! 'schema.rakuconf');
        my $file = $!config.directory.add($version<path>).add($name);
        self!error("Modified adopted snapshot: $file")
            unless $file.f && self!checksum($file.slurp) eq $version<checksums>{$name}<checksum>;
        my $historical = Red::Migration::Snapshot.load($file);
        for $historical.tables -> $table {
            self!error("Adopted table conflicts with local schema: {$table.name}")
                if %merged{$table.name}:exists;
            %merged{$table.name} = $table;
        }
    }
    $snapshot = Red::Migration::Snapshot.new(:tables(%merged.values.sort(*.name).Array));
    $snapshot
}

# Adoption is a metadata event at an existing migration ID. Include its baseline in
# subsequent rebased schemas without generating CREATE SQL for already imported tables.
method !activate-adoptions(Str $anchor, %schema) {
    my %state = import-state($!config.directory);
    for (%state<adoptions> // {}).values -> $adoption {
        for $adoption<versions>.values.grep(*.<anchor> eq $anchor) -> $version {
            my $name = $version<names><logical> // 'schema.rakuconf';
            my $file = $!config.directory.add($version<path>).add($name);
            self!error("Modified adopted snapshot: $file")
                unless $file.f && self!checksum($file.slurp) eq $version<checksums>{$name}<checksum>;
            my %incoming = schema-data(Red::Migration::Snapshot.load($file));
            for %incoming<tables>.kv -> $name, $table {
                self!error("Adopted table conflicts with serialized schema: $name")
                    if %schema<tables>{$name}:exists;
                %schema<tables>{$name} = $table;
            }
        }
    }
    %schema
}

method !snapshot-through(%by-id, Str $id) {
    my @ancestors;
    my %seen;
    my $cursor = $id;
    while $cursor.chars {
        self!error('Incomplete or cyclic snapshot ancestry')
            if %seen{$cursor}++ || !(%by-id{$cursor}:exists);
        @ancestors.unshift: %by-id{$cursor}.item;
        $cursor = %by-id{$cursor}<predecessor>;
    }
    self!local-snapshot(@ancestors)
}

#| Adopt published history without evaluating dependency artifacts or changing the database.
method adopt(Str :$dependency!, IO() :$project = '.', :@bundles) {
    with-history-lock($!config.directory, {
        my %initial = import-state($!config.directory);
        self!error("Dependency already adopted: $dependency") if %initial<adopted>{$dependency};
        self!error('Prepare or remove drafts before adopting')
            if self!entries.grep({ (.<state> // '') eq 'draft' });
        my @sources = @bundles ?? @bundles !! discover-bundles($project);
        my @matches = @sources.grep(*.identity eq $dependency);
        self!error("Expected one installed migration bundle for $dependency") unless @matches == 1;
        my $bundle = @matches[0];
        my @history = self!history;
        my %known = @history.map({ .<id> => $_ });
        my @existing = @history.grep({ (.<origin><identity> // '') eq $dependency });
        my $last = @existing ?? @existing.tail<id> !! '';
        my %entries = $bundle.migrations.map({ .<id> => $_ });
        self!error("Bundle does not contain last imported version: $last")
            if $last.chars && !(%entries{$last}:exists);
        # SQL-only legacy bundles cannot establish a historical baseline. Intermediate
        # execution-only versions are valid when a later complete baseline is supplied.
        my $final = $bundle.migrations.tail;
        self!error('Cannot adopt an empty migration bundle') unless $final.defined;
        my %baseline-names = logical => 'schema.rakuconf';
        %baseline-names{$_} = "$_/schema.rakuconf" for $!config.drivers;
        %baseline-names = $final<baseline> if $final<baseline>.defined;
        for ('logical', |$!config.drivers) -> $driver {
            my $name = %baseline-names{$driver};
            self!error("Publish a complete bundle before adopting: {$final<id>}/$driver snapshot")
                unless $name.defined && ($final<artifacts>{$name}:exists);
        }
        make-directory($!config.directory);
        my $stage = staging-history($!config.directory);
        LEAVE discard-staging-history($stage) if $stage.defined && $stage.e;
        my $manager = self.WHAT.new(:config($!config.clone(:directory($stage))));
        $manager.import(:bundles[$bundle]);
        my @updated = $manager.history;
        my %state = import-state($stage);
        my %versions;
        for @updated.grep({ (.<origin><identity> // '') eq $dependency }) -> %migration {
            my $id = %migration<id>;
            next if %known{$id}:exists && $id ne $last;
            my $entry = %entries{$id};
            my $existing = %known{$id}:exists;
            my $relative = $existing ?? ".adopt-$id" !! %migration<path>.basename;
            my $target = $stage.add($relative);
            make-directory($target);
            my %sql-files;
            for ($entry<sql-files> // {}).kv -> $driver, $files {
                %sql-files{"$driver/$_"} = True for $files.keys;
            }
            for $entry<artifacts>.kv -> $name, $source {
                if $existing {
                    next unless $name eq 'schema.rakuconf'
                        || $name ~~ /^ <[A..Za..z]>+ '/schema.rakuconf' $/
                        || $name eq any(($entry<baseline> // {}).values);
                } else {
                    # SQL was copied by import, retaining names and file checkpoint identities.
                    next if %sql-files{$name}:exists;
                }
                my $destination = $target.add($name eq 'migration.rakuconf'
                    ?? '.origin/' ~ nqp::sha1($dependency) ~ '-migration.rakuconf' !! $name);
                make-directory($destination.parent);
                $destination.spurt($source);
            }
            if $id eq $final<id> || $existing {
                my %names = logical => 'schema.rakuconf';
                %names{$_} = "$_/schema.rakuconf" for $!config.drivers;
                %names = $entry<baseline> if $entry<baseline>.defined;
                if %names.values.grep({ !($entry<artifacts>{$_}:exists) }).elems == 0 {
                    %versions{$id} = %(path => $relative, names => %names,
                        anchor => ($existing ?? (@history ?? @history.tail<id> !! '') !! $id),
                        checksums => $entry<files>);
                }
            }
        }
        my @tables = %state<tables>.keys.grep({ %state<tables>{$_} eq $dependency });
        %state<tables>{$_}:delete for @tables;
        %state<adopted>{$dependency} = True;
        %state<adoptions>{$dependency} = %(versions => %versions, tables => @tables.Array);
        write-import-state($stage, %state);
        publish-history($!config.directory, $stage);
        @tables.elems
    }, :!wait)
}

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
                :external-tables(self!external-tables),
                :driver(self!driver($dialect)), :$dialect).capture(self!models);
        }
        my $target = logical-capture(self!models, %snapshots, $!config.drivers);
        my $before = self!local-snapshot(@history);
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
    my $planner = Red::Migration::Planner.new(:external-tables(self!external-tables), :$driver, :$dialect);
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
        my $planner = Red::Migration::Planner.new(:external-tables(self!external-tables), :driver($db), :$dialect);
        my $new = $planner.capture(self!models);
        %snapshots{$dialect} = $new;
        my $old = Red::Migration::Snapshot.new;
        $old = self!local-snapshot(@history, :driver($dialect));
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
    my $logical = logical-capture(self!models, %snapshots, $!config.drivers);
    my $logical-source = $logical.source;
    my %before = tables => {};
    if @history { %before = schema-data(self!local-snapshot(@history)) }
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
        unless %m<imported> {
            my $snapshot = $dir.add('schema.rakuconf').slurp;
            self!error("Modified snapshot: {%m<id>}")
                unless self!checksum($snapshot) eq %m<drivers>{$dialect}<snapshot-checksum>;
        }
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
    return if %migration<imported>;
    my $index = @history.first(*.<id> eq %migration<id>, :k);
    my $current = Red::Migration::Snapshot.load(
        %migration<path>.add($dialect).add('schema.rakuconf'));
    my $previous = self!local-snapshot(@history[^$index], :driver($dialect));
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
            Bool :$report = False, Str :$to, :$database, Bool :$already-locked = False) {
    self!error('Run migrations outside an existing Red transaction') if CALLERS::<$*RED-TRANSACTION-RUNNING>;
    my $locked = False;
    my $pg-open = False;
    my $db = $database // self!connection($connection);
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
    unless $already-locked {
        self!lock($db, $dialect, :read-only($inspect));
        $locked = True;
    }
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
                if !%m<imported> && $sql.uc.contains('NOT NULL') && $sql.uc.starts-with('ALTER TABLE ') {
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
#| Reconcile a manually repaired MySQL execution without executing migration SQL.
method resolve(Str $id, Str :$as!, Str :$reason!, Str :$connection = 'default' --> Hash) {
    CATCH {
        when X::Red::Migration { .rethrow }
        default { self!error("Cannot reconcile migration $id: {.message}") }
    }
    self!error('Resolution state must be applied or reverted') unless $as eq any(<applied reverted>);
    self!error('A non-empty reconciliation reason is required') unless $reason.trim.chars;
    self!error('Resolve migrations outside an existing Red transaction')
        if CALLERS::<$*RED-TRANSACTION-RUNNING>;
    with-history-lock($!config.directory, {
        self!error('Prepare or remove migration drafts before resolving')
            if self!entries.grep({ (.<state> // '') eq 'draft' });
        my $locked = False;
        my $db = self!connection($connection);
        self!error('Explicit reconciliation is supported only for MySQL')
            unless self!dialect($db) eq 'MySQL';
        my $*RED-DB = $db;
        my $*RED-TRANSACTION-RUNNING = True;
        my @history = self!scripts(self!history, 'MySQL');
        my $index = @history.first(*.<id> eq $id, :k);
        self!error("Unknown migration: $id") unless $index.defined;
        my %migration = @history[$index];
        self!lock($db, 'MySQL');
        LEAVE self!unlock($db, 'MySQL') if $locked;
        $locked = True;
        my @tables = $db.schema-reader.tables-names.List;
        self!error('Migration execution records are not initialized')
            unless 'red_migrations' eq any(@tables) && 'red_migration_files' eq any(@tables);
        my @rows = Red::Migration::Applied.^all.List;
        my $row = @rows.first(*.id eq $id);
        self!error("Migration $id has no unresolved execution")
            unless $row.defined && $row.state eq any(<running failed>);
        self!error('Resolve exactly one outstanding execution at a time')
            unless @rows.grep({ .state ne any(<applied reverted>) }).elems == 1;
        self!validate(@history, @rows, :allow-unresolved);
        my $gap = False;
        for @history -> %entry {
            my $record = @rows.first(*.id eq %entry<id>);
            my $state = %entry<id> eq $id ?? $as !! ($record.defined ?? $record.state !! 'pending');
            self!error('Resolution would introduce a migration history gap') if $gap && $state eq 'applied';
            $gap = True unless $state eq 'applied';
        }
        self!error('Invalid execution direction') unless $row.direction eq any(<up down>);
        my @files = Red::Migration::File.^all.grep(*.migration-id eq $id).List;
        for @files -> $file {
            self!error('Invalid file checkpoint direction') unless $file.direction eq any(<up down>);
            my $expected = %migration{"{$file.direction}-files"}.first(*.<file> eq $file.file);
            self!error("Modified or missing checkpoint file: {$file.file}")
                unless $expected.defined && $expected<checksum> eq $file.checksum
                    && $file.id eq self!checksum("$id|{$file.direction}|{$file.file}");
            my $total = %migration{"{$file.direction}-instructions"}.grep(*.<file> eq $file.file).elems;
            self!error('Invalid observed file statement count')
                unless 0 <= $file.completed-statements <= $total;
        }
        self!error('Invalid observed migration statement count')
            unless 0 <= $row.completed-statements <= %migration{"{$row.direction}-instructions"}.elems;
        my @prefix = @history[^($index + ($as eq 'applied' ?? 1 !! 0))];
        my $verification = self!verify-prefix($db, 'MySQL', @prefix);
        my %before = <id predecessor up-checksum down-checksum state direction applied-at reverted-at completed-statements>
            .map({ $_ => $row."$_"() });
        my @before-files = @files.map(-> $file {
            %( <id migration-id direction file checksum state completed-statements>
                .map({ $_ => $file."$_"() }) )
        });
        Red::Migration::Resolution.^create-table(:if-not-exists);
        my $timestamp = DateTime.now.Str;
        $db.dbh.execute('START TRANSACTION');
        try {
            $row.state = $as;
            if $as eq 'applied' { $row.applied-at = $timestamp }
            else { $row.reverted-at = $timestamp }
            $row.^save;
            for %migration{"{$row.direction}-files"}.list -> %file {
                my $record = @files.first({ .direction eq $row.direction && .file eq %file<file> });
                if $record.defined {
                    $record.state = 'resolved';
                    $record.^save;
                } else {
                    Red::Migration::File.^create(:id(self!checksum("$id|{$row.direction}|{%file<file>}")),
                        :migration-id($id), :direction($row.direction), :file(%file<file>),
                        :checksum(%file<checksum>), :state<resolved>, :completed-statements(0));
                }
            }
            Red::Migration::Resolution.^create(:id(UUID.new.Str), :migration-id($id),
                :before-state(%before<state>), :after-state($as), :direction(%before<direction>),
                :reason($reason.trim), :resolved-at($timestamp), :$verification,
                :version-data(to-json(%before, :sorted-keys)),
                :checkpoint-data(to-json(@before-files.Array, :sorted-keys)));
            $db.dbh.execute('COMMIT');
            CATCH { default { try $db.dbh.execute('ROLLBACK'); .rethrow } }
        }
        %(id => $id, state => $as, :$verification, data-verified => False)
    })
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
#| Drop configured and historical managed tables, together with all migration bookkeeping.
#| An optional confirmation callback receives the ordered table names before any DDL executes.
method drop-tables(Str :$connection = 'default', Callable :$confirm) {
    with-history-lock($!config.directory, { self!rebuild($connection, :$confirm) })
}

#| Drop managed tables and replay the prepared history on the same pinned connection.
#| Fixtures are not applied. Existing migration locking and per-dialect execution rules apply.
method reset(Str :$connection = 'default', Callable :$confirm) {
    with-history-lock($!config.directory, { self!rebuild($connection, :$confirm, :reset) })
}

method !rebuild(Str $connection, Callable :$confirm, Bool :$reset = False) {
    self!error('Run table removal outside an existing Red transaction')
        if CALLERS::<$*RED-TRANSACTION-RUNNING>;
    my $db = self!connection($connection);
    my $dialect = self!dialect($db);
    my $session;
    if $dialect eq 'Pg' && $db.dbh.^name eq 'DB::Pg' {
        $session = $db.dbh.db;
        $db = $db.new-connection($session);
    }
    LEAVE $session.finish if $session.defined;
    my $*RED-DB = $db;
    my $locked = False;
    my $transaction-open = False;
    LEAVE { self!unlock($db, $dialect) if $locked }
    CATCH {
        default {
            try $db.execute('ROLLBACK') if $transaction-open;
            .rethrow;
        }
    }
    my @history = self!history;
    if $reset {
        self!scripts(@history, $dialect);
        self!error('Unprepared migration drafts exist; run red migration prepare first')
            if self!entries.grep({ (.<state> // '') eq 'draft' });
    }
    my %wanted;
    for $!config.model-types -> $model {
        self!error("Views and temporary models cannot be dropped: {$model.^name}")
            if $model.^temp || $model.HOW.^name.contains('View');
        %wanted{$model.^table} = True;
    }
    for @history -> %migration {
        if %migration<imported> {
            my %changes = %migration<origin><tables> // {};
            %wanted{$_} = True for |(%changes<create> // []), |(%changes<drop> // []),
                |(%changes<rename> // {}).keys, |(%changes<rename> // {}).values;
        } else {
            my $snapshot = %migration<path>.add("$dialect/schema.rakuconf");
            self!error("Missing historical snapshot: $snapshot") unless $snapshot.f;
            %wanted{.name} = True for Red::Migration::Snapshot.load($snapshot).tables;
        }
    }
    %wanted{$_} = True for <red_migrations red_migration_files red_migration_resolutions>;
    self!lock($db, $dialect);
    $locked = True;
    $transaction-open = $dialect eq 'SQLite';
    my @existing = $db.schema-reader.tables-names.grep({ .defined && $_ ne 'sqlite_sequence' }).List;
    my %dependencies;
    for @existing -> $table {
        my $definition = $db.schema-reader.table-definition($table);
        my @references = $definition.columns.map({ .references<table> // () }).flat.unique;
        if !(%wanted{$table}:exists) && @references.grep({ %wanted{$_}:exists }) {
            self!error("Unmanaged table $table references a table selected for removal");
        }
        %dependencies{$table} = @references.Array;
    }
    my @pending = @existing.grep({ %wanted{$_}:exists }).sort;
    my @tables;
    while @pending {
        my @ready = @pending.grep(-> $candidate {
            !@pending.grep(-> $other {
                $other ne $candidate && $candidate eq any(%dependencies{$other})
            }).elems
        });
        self!error('Cyclic table dependencies prevent removal; use an explicit migration')
            unless @ready;
        @tables.append(@ready);
        @pending = @pending.grep({ $_ ne any(@ready) });
    }
    # Keep execution evidence until application tables have been removed on nontransactional DDL.
    my %bookkeeping = set <red_migrations red_migration_files red_migration_resolutions>;
    @tables = (|@tables.grep({ !(%bookkeeping{$_}:exists) }),
        |@tables.grep({ %bookkeeping{$_}:exists }));
    self!error('Cancelled; no tables were removed')
        if $confirm.defined && !$confirm(@tables.Array);
    if $dialect eq 'Pg' {
        self!execute($db, 'BEGIN');
        $transaction-open = True;
    }
    self!execute($db, 'DROP TABLE ' ~ $db.table-name-wrapper($_)) for @tables;
    unless $reset && $dialect eq 'SQLite' {
        self!execute($db, 'COMMIT') if $transaction-open;
        $transaction-open = False;
    }
    if $reset {
        my $applied = self!run($connection, :database($db), :already-locked);
        $transaction-open = False;
        return $applied;
    }
    @tables.elems
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
    my $planner = Red::Migration::Planner.new(:external-tables(self!external-tables), :driver($db), :$dialect);
    my $target = $planner.capture(self!models);
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
        my $model = self!models.first(*.^table eq $table.name);
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
                    my @libraries = $*REPO.repo-chain.grep({
                        $_ ~~ CompUnit::Repository::FileSystem
                            || $_ ~~ CompUnit::Repository::Installation
                    }).map(*.path-spec);
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
    self!error('Imported SQL cannot be regenerated or serialized; prepare it in its distribution')
        if %migration<imported>;
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
        my $planner = Red::Migration::Planner.new(:external-tables(self!external-tables), :driver($backend), :dialect($driver));
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
        my %by-id = @history.map({ .<id> => $_ });
        my $count = 0;
        for @history -> %migration {
            self!error("Dependency must publish $driver SQL for {%migration<id>}")
                if %migration<imported> && !(%migration<drivers>{$driver}:exists);
            next if %migration<imported>;
            my $previous = self!snapshot-through(%by-id, %migration<predecessor>);
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
    my $index = $last.defined ?? @history.first(*.<id> eq $last<id>, :k) + 1 !! 0;
    my @prefix = @history[^$index];
    self!verify-prefix($db, $driver, @prefix);
    True
}

method !verify-prefix($db, Str $driver, @prefix) {
    my $snapshot = self!local-snapshot(@prefix, :$driver);
    my %external;
    for @prefix.grep(*.<imported>) -> %migration {
        my %changes = %migration<origin><tables> // {};
        %external{$_} = %migration<origin><identity> for (%changes<create> // []).list;
        for (%changes<rename> // {}).kv -> $old, $new {
            %external{$new} = %external{$old}:delete;
        }
        %external{$_}:delete for (%changes<drop> // []).list;
    }
    my %adoptions = import-state($!config.directory)<adoptions> // {};
    my %positions = @prefix.kv.map(-> $index, $entry { $entry<id> => $index });
    my @local = @prefix.grep({ !.<imported> });
    my $local-position = @local ?? %positions{@local.tail<id>} !! -1;
    for %adoptions.kv -> $identity, $adoption {
        my @anchors = $adoption<versions>.values.grep({ %positions{.<anchor>}:exists });
        next unless @anchors;
        if @anchors.map({ %positions{.<anchor>} }).max < $local-position {
            for $adoption<tables>.list -> $table {
                %external{$table}:delete if (%external{$table} // '') eq $identity;
            }
        }
    }
    %external{.name}:delete for $snapshot.tables;
    my @actual = $db.schema-reader.tables-names.grep({ .defined && !($_ eq any(<red_migrations red_migration_files red_migration_resolutions sqlite_sequence>)) }).sort;
    my @wanted = (|$snapshot.tables.map(*.name), |%external.keys).unique.sort;
    self!error('Database table set differs from the migration snapshot') unless @actual eqv @wanted;
    for $snapshot.tables -> $table {
        my $actual = $db.schema-reader.table-definition($table.name);
        self!error("Database schema differs from snapshot: {$table.name}") if $actual.diff($table).elems;
        for $table.indexes -> %index {
            self!error("Missing index {%index<name>}")
                unless $db.indexes-for-table($table.name).first(*.<name> eq %index<name>).defined;
        }
    }
    $snapshot.tables.elems == @wanted.elems ?? 'schema' !! 'tables-only'
}
#| Rebase unpublished branches after a protected prefix in the requested tip order. Reject conflicts
#| and custom SQL, regenerate affected artifacts with stable IDs, and validate before atomic
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
        my %state = schema-data(self!snapshot-through(%by-id, $after));
        my $previous = $after;
        my $changed = 0;
        for @sequence -> $original-id {
            my %migration = %by-id{$original-id};
            my %before = schema-data(self!snapshot-through(%by-id, %migration<predecessor>));
            my %target = schema-data(self!logical(%migration));
            my @operations = changes(%before, %target);
            my $stored = self!load(%migration<path>.add('operations.rakuconf'));
            self!error("Modified portable operations: $original-id") unless @operations eqv $stored.list.Array;
            my %merged = rebase(%state, @operations);
            if !%rewritten{$original-id} {
                $previous = $original-id;
                %state = self!activate-adoptions($original-id, %merged);
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
            my $id = $original-id;
            remove-tree($stage.add(%migration<path>.basename));
            my $directory = $stage.add(%migration<path>.basename);
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
                :%drivers, logical-checksum => self!checksum($source);
            %manifest<replaces> = %migration<replaces> if %migration<replaces>.defined;
            if $data.defined {
                $directory.add('migration.raku').spurt($data);
                $directory.add('before.rakuconf').spurt($old.source);
                %manifest<data-checksum> = self!checksum($data);
                %manifest<before-checksum> = self!checksum($old.source);
                %manifest<state> = 'prepared';
            }
            $directory.add('migration.rakuconf').spurt(artifact-source('manifest', %manifest));
            $previous = $id;
            %state = self!activate-adoptions($original-id, %merged);
            $changed++;
        }
        my $config = $!config.clone(:directory($stage));
        self.WHAT.new(:$config).test;
        publish-history($!config.directory, $stage) if $changed;
        $changed
    }, :!wait)
}
