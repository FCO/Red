use JSON::Fast;
use nqp;
use Red::Migration::Artifact;
use Red::Migration::Storage;
use Red::Migration::Scripts;
use Red::Migration::Snapshot;
use X::Red::Migration;

unit module Red::Migration::Import;

sub reject(Str $reason) {
    X::Red::Migration.new(:$reason).throw
}

sub import-state(IO() $directory --> Hash) is export {
    my $file = $directory.add('.dependencies.json');
    $file.f ?? from-json($file.slurp) !! %(records => {}, tables => {}, adopted => {})
}

sub write-import-state(IO() $directory, %state) is export {
    $directory.add('.dependencies.json').spurt(to-json(%state, :sorted-keys));
}

sub import-bundles(IO() $directory, @history, @bundles, @drivers --> Int) is export {
    my %state = import-state($directory);
    my %known = @history.map({ .<id> => $_ });
    my %pending;
    for @bundles -> $bundle {
        for $bundle.migrations -> $entry {
            my %entry = $entry.Hash;
            my $id = %entry<id>;
            my %source = %entry;
            %source<sql>:delete;
            %source<sql-files>:delete;
            %source<artifacts>:delete;
            my $fingerprint = nqp::sha1(to-json(%source, :sorted-keys));
            if %known{$id}:exists {
                my $record = %state<records>{$id};
                reject("Migration ID collision: $id")
                    unless $record.defined && $record<identity> eq $bundle.identity;
                reject("Published migration changed: $id") unless $record<checksum> eq $fingerprint;
                next;
            }
            reject("Schema was adopted locally: {$bundle.identity}") if %state<adopted>{$bundle.identity};
            reject("Migration ID collision: $id") if %pending{$id}:exists;
            reject("Invalid migration name: $id")
                unless (%entry<name> // '') ~~ /^ <[A..Za..z0..9_-]>+ $/;
            reject("Migration $id requires table ownership metadata") unless %entry<tables> ~~ Associative;
            for <create drop> -> $action {
                reject("Invalid table ownership list: $id/$action")
                    if %entry<tables>{$action}:exists && %entry<tables>{$action} !~~ Array;
                for (%entry<tables>{$action} // []).list -> $table {
                    reject("Invalid table name: $id/$action") unless $table ~~ Str && $table.chars;
                    reject("Reserved migration table: $table")
                        if $table eq any(<red_migrations red_migration_files red_migration_resolutions>);
                }
            }
            reject("Invalid table rename metadata: $id")
                if %entry<tables><rename>:exists && %entry<tables><rename> !~~ Associative;
            for @drivers -> $driver {
                reject("Dependency must publish $driver SQL for $id") unless %entry<sql>{$driver}:exists;
            }
            %pending{$id} = %(entry => %entry, identity => $bundle.identity,
                version => $bundle.version, checksum => $fingerprint);
        }
    }
    my @ordered;
    while %pending {
        my $progress = False;
        for %pending.keys.sort -> $id {
            my %item = %pending{$id};
            my %entry = %item<entry>;
            my @requirements = (%entry<requires> // []).list;
            my $predecessor = %entry<predecessor> // '';
            @requirements.push: %(identity => %item<identity>, id => $predecessor)
                if $predecessor.chars;
            my $ready = True;
            for @requirements -> $requirement {
                reject("Invalid migration requirement: $id")
                    unless $requirement ~~ Associative && $requirement<id> ~~ Str
                        && $requirement<identity> ~~ Str;
                my $required = $requirement<id>;
                if %pending{$required}:exists { $ready = False; next }
                my $record = %state<records>{$required};
                reject("Missing or incompatible original predecessor/requirement: $id -> $required")
                    unless %known{$required}:exists && $record.defined
                        && $record<identity> eq $requirement<identity>;
            }
            next unless $ready;
            my %tables = %entry<tables>;
            for (%tables<create> // []).list -> $table {
                reject("Table ownership conflict: $table") if %state<tables>{$table}:exists;
                %state<tables>{$table} = %item<identity>;
            }
            for (%tables<rename> // {}).kv -> $old, $new {
                reject("Table ownership conflict: $old -> $new")
                    unless (%state<tables>{$old} // '') eq %item<identity>
                        && !(%state<tables>{$new}:exists);
                %state<tables>{$old}:delete;
                %state<tables>{$new} = %item<identity>;
            }
            for (%tables<drop> // []).list -> $table {
                reject("Table ownership conflict: $table")
                    unless (%state<tables>{$table} // '') eq %item<identity>;
                %state<tables>{$table}:delete;
            }
            %state<records>{$id} = %(identity => %item<identity>, version => %item<version>,
                checksum => %item<checksum>, predecessor => $predecessor,
                tables => %entry<tables>);
            %known{$id} = %entry;
            @ordered.push: %item;
            %pending{$id}:delete;
            $progress = True;
        }
        reject('Dependency migration history contains a cycle') unless $progress;
    }
    return 0 unless @ordered;
    make-directory($directory);
    my $stage = staging-history($directory);
    LEAVE discard-staging-history($stage) if $stage.defined && $stage.e;
    my $previous = @history ?? @history.tail<id> !! '';
    for @ordered -> %item {
        my %entry = %item<entry>;
        my $id = %entry<id>;
        my $path = $stage.add("$id-{%entry<name>}");
        make-directory($path);
        my %drivers;
        for %entry<sql>.kv -> $driver, $directions {
            my $target = $path.add($driver);
            make-directory($target);
            if %entry<sql-files>{$driver}:exists {
                for %entry<sql-files>{$driver}.kv -> $name, $source {
                    my $file = $target.add($name);
                    make-directory($file.parent);
                    $file.spurt($source);
                }
            } else {
                $target.add('up.sql').spurt($directions<up>);
                $target.add('down.sql').spurt($directions<down>);
            }
            read-direction($target, $_, $driver) for <up down>;
            %drivers{$driver} = %entry<manifest><drivers>{$driver}:exists
                ?? %entry<manifest><drivers>{$driver}.Hash
                !! %(reversible => True, down-state => 'available', down-reason => '');
        }
        $path.add('migration.rakuconf').spurt(artifact-source('manifest', %(
            format => 2, :$id, name => %entry<name>, predecessor => $previous,
            imported => True, origin => %state<records>{$id}, :%drivers)));
        $previous = $id;
    }
    write-import-state($stage, %state);
    publish-history($directory, $stage);
    @ordered.elems
}
