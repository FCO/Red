unit class Red::Cli;
use Red::Database;
use Red::DB;
use Red::Do;
use Red::Schema;
use Red::Utils;
use Red::AST::CreateColumn;
use Red::AST::ChangeColumn;
use Red::AST::DropColumn;
use Red::AST::CreateTable;
use Red::Configuration;

#| Lists tables from database schema
multi list-tables(
        Str  :$driver!,
        *%pars
) is export {
    my $schema-reader = get-RED-DB.schema-reader;
    $schema-reader.tables-names.do-it
}

sub gen-stub(:@includes, :@models, :$driver, :%pars) {
    my @stub;
    @stub.push: 'use Red:api<2>;';
    for @includes.unique {
        @stub.push: "use $_;"
    }
    @stub.push: "\nred-defaults \"{ $driver }\", { %pars.map(*.raku) };\n";
    @stub.push: "";
    for @models {
        @stub.push: ".say for { $_ }.^all;"
    }
    @stub
}

#| Generates stub code to access models from database schema
multi gen-stub-code(
        Str  :$schema-class,
        Str  :$driver!,
        *%pars
) is export {
    my $schema-reader = get-RED-DB.schema-reader;
    my @includes;
    my @models;
    for $schema-reader.tables-names -> $table-name {
        my $model-name = snake-to-camel-case $table-name;
        @models.push: $model-name;
        with $schema-class {
            @includes.push: $schema-class;
        } else {
            @includes.push: $model-name;
        }
    }
    gen-stub(:@includes, :@models, :$driver, :%pars).join: "\n"
}

#| Generates migration plan to upgrade database schema
multi migration-plan(
        Str :$model!,
        Str :$require = $model,
        Str :$driver!,
        *%pars
) is export {
    require ::($require);
    for get-RED-DB.diff-to-ast: ::($model).^diff-from-db -> @data {
        say "Step ", ++$, ":";
        get-RED-DB.translate($_).key.indent(4).say for @data
    }
}

#| Generates models' code from database schema
multi generate-code(
        Str  :$path!    where { not .defined or .IO.d or $_ eq "-" or fail "Path $_ does not exist." },
        Str  :$from-sql where { not .defined or .IO.f or $_ eq "-" or fail "SQL $_ do not exist." },
        Str  :$schema-class,
        Bool :$print-stub       = False,
        Bool :$no-relationships = False,
        Str  :$driver!,
        *%pars
) is export {
    my $schema-reader = get-RED-DB.schema-reader;

    my $schema = do if $path eq "-" {
        $*OUT
    } else {
        $path.IO.add("$_.pm6").open: :!bin, :w with $schema-class
    }

    my $sql = $from-sql eq "-" ?? $*IN !! .IO.open with $from-sql;

    my Bool $no-use = False;
    my @includes;
    my @models;
    for |(
            $sql
                    ?? $sql.slurp
                    !! $schema-reader.tables-names
            ) -> $name-or-sql {
        for |(
                $name-or-sql.contains(" ")
                        ?? $schema-reader.table-definition-from-create-table($name-or-sql)
                        !! $schema-reader.table-definition($name-or-sql)
                ) -> $table-definition {
            my $table-name = $table-definition.name;
            my $model-name = $table-definition.model-name;
            @models.push: $model-name;
            my $fh = do with $schema {
                @includes.push: $schema-class if $schema-class;
                $_
            } else {
                @includes.push: $model-name;
                $path.IO.add("{ $model-name }.pm6").open: :!bin, :w
            }
            $fh.say: "use Red;\n" unless $no-use;
            $fh.say: "#| Table: $table-name";
            $fh.say: $table-definition.to-code:
                    :$no-relationships,
                    |(:$schema-class with $schema-class)
            ;
            with $schema {
                $no-use++ if $schema-class
            } else {
                $fh.close unless $path eq "-";
            }
        }
    }
    $schema.close if $schema.defined and $path ne "-";
    gen-stub :@includes, :@models, :$driver, :%pars if $print-stub
}

#| Prepare database
multi prepare-database(
        Bool :$populate,
        Str  :$models!,
        Str  :$driver!,
        *%pars
) is export {
    my @m = schema($models.split: ",").create.models.values;
    @m.map: { .^populate } if $populate
}

#============================================
# MIGRATION COMMANDS
#============================================

#| Update the local database to match the current model definitions.
#| Saves a snapshot of the current model for later diffing.
multi migration-update(
        Str :$model!,
        Str :$require = $model,
        Str :$driver!,
        Str :$config-path = "migration.rakuconfig",
        *%pars
) is export {
    my $config = Red::Configuration.new:
        :base-path($*CWD),
        :drivers[$driver],
    ;
    $config.ensure-dirs;

    require ::($require);

    my $model-class = ::($model);
    my $model-name  = $model-class.^name;
    my $table-name  = $model-class.^table;

    # 1. Compute the diff between DB and model FIRST — avoid creating empty versions
    my @diffs = $model-class.^diff-from-db;
    unless @diffs {
        note "No changes detected for $model-name (table: $table-name)";
        return;
    }

    # 2. Allocate new version only when there are actual changes
    my $version = $config.current-version + 1;
    $config.store-version: $version, "update $model-name";

    # 3. Convert diffs to AST
    my @asts;
    for get-RED-DB.diff-to-ast(@diffs) -> @data {
        @asts.append: @data;
    }

    # 4. Apply each AST to the local DB
    for @asts -> $ast {
        note "Applying: { get-RED-DB.translate($ast).key }";
        get-RED-DB.execute: $ast;
    }

    # 5. Save model description snapshot (for future prepare)
    my $desc = $model-class.^describe;
    my $snapshot-path = $config.model-storage-path.add: "{ $model-name }-{ $version }.rakudata";
    $snapshot-path.spurt: $desc.raku;

    # 6. Update current version
    $config.current-version = $version;
    $config.version-dir($version).add("config.rakudata").spurt: $config.raku;

    note "Migration v{ $version } applied. Snapshot saved to { $snapshot-path.relative($*CWD) }";
    $version
}

#| Downgrade the local database by restoring from a dump file.
#| Note: currently requires manual dump management; focuses on schema rollback.
multi migration-downgrade(
        Str :$driver!,
        Str :$config-path = "migration.rakuconfig",
        *%pars
) is export {
    my $config = Red::Configuration.new:
        :base-path($*CWD),
        :drivers[$driver],
    ;

    my $version = $config.current-version;
    if $version < 1 {
        note "No migrations to downgrade (current version: $version)";
        return;
    }

    note "Downgrading from version $version...";

    # Apply the down.sql for the current version
    for $config.drivers -> $drv {
        my $down-file = $config.down-sql($drv, $version);
        if $down-file.f {
            note "Running down migration: { $down-file.relative($*CWD) }";
            for $down-file.lines -> $sql {
                next if $sql.trim eq '' || $sql.trim.starts-with('--');
                get-RED-DB.execute: $sql;
            }
        } else {
            note "No down.sql found for $drv v$version";
        }
    }

    $config.current-version = $version - 1;
    note "Downgraded to version { $config.current-version }";
}

#| Generate SQL migration files (up.sql and down.sql) by comparing
#| the versioned model snapshot with the current model definition.
multi migration-prepare(
        Str :$model!,
        Str :$require = $model,
        Str :$driver!,
        Str :$config-path = "migration.rakuconfig",
        *%pars
) is export {
    my $config = Red::Configuration.new:
        :base-path($*CWD),
        :drivers[$driver],
    ;
    $config.ensure-dirs;

    require ::($require);
    my $model-class = ::($model);
    my $model-name  = $model-class.^name;

    # 1. Find the latest model snapshot
    my @snapshots = $config.model-storage-path.dir
        .grep: { .basename.starts-with($model-name ~ '-') && .extension eq 'rakudata' }
        .sort: { .modified }
    ;

    unless @snapshots {
        note "No previous model snapshot found for $model-name.";
        note "Run 'red migration update' first to create a snapshot, or create an initial SQL file manually.";
        return;
    }

    my $snapshot-file = @snapshots.tail;
    note "Using snapshot: { $snapshot-file.relative($*CWD) }";

    # 2. Load the old model description from snapshot
    my $old-desc-str = $snapshot-file.slurp;
    use MONKEY-SEE-NO-EVAL;
    my $old-desc = EVAL $old-desc-str;

    # 3. Get current model description
    my $new-desc = $model-class.^describe;

    # 4. Compute diffs
    my @up-diffs   = $old-desc.diff: $new-desc;    # old → new
    my @down-diffs = $new-desc.diff: $old-desc;    # new → old

    # 5. Generate SQL for each driver
    my $version = $config.current-version + 1;
    for $config.drivers -> $drv {
        # Temporarily set up the driver for translation
        my $*RED-DB = database($drv, |%pars);

        # Generate up.sql
        my $up-dir = $config.sql-dir-for($drv, $version);
        $up-dir.mkdir: :p;
        my $up-file = $config.up-sql($drv, $version);
        my $up-fh = $up-file.open: :w;
        $up-fh.say: "-- Red Migration v$version: $model-name (UP)";
        $up-fh.say: "-- Generated: { DateTime.now }";
        $up-fh.say: "-- Driver: $drv";
        $up-fh.say: "";
        if @up-diffs {
            my @asts;
            for $*RED-DB.diff-to-ast(@up-diffs) -> @data {
                @asts.append: @data;
            }
            for @asts -> $ast {
                my ($sql, @bind) = $*RED-DB.translate($ast).kv;
                $up-fh.say: "$sql;" if $sql;
            }
        } else {
            $up-fh.say: "-- No schema changes";
        }
        $up-fh.close;
        note "Generated: { $up-file.relative($*CWD) }";

        # Generate down.sql
        my $down-file = $config.down-sql($drv, $version);
        my $down-fh = $down-file.open: :w;
        $down-fh.say: "-- Red Migration v$version: $model-name (DOWN)";
        $down-fh.say: "-- Generated: { DateTime.now }";
        $down-fh.say: "-- Driver: $drv";
        $down-fh.say: "";
        if @down-diffs {
            my @asts;
            for $*RED-DB.diff-to-ast(@down-diffs) -> @data {
                @asts.append: @data;
            }
            for @asts -> $ast {
                my ($sql, @bind) = $*RED-DB.translate($ast).kv;
                $down-fh.say: "$sql;" if $sql;
            }
        } else {
            $down-fh.say: "-- No schema changes";
        }
        $down-fh.close;
        note "Generated: { $down-file.relative($*CWD) }";
    }

    $config.store-version: $version, "prepare $model-name";
    note "Migration v$version prepared successfully.";
}

#| Apply pending SQL migrations to the target database.
#| Reads the version from a tracking table and applies all newer up.sql files.
multi migration-apply(
        Str :$driver!,
        Str :$config-path = "migration.rakuconfig",
        *%pars
) is export {
    my $config = Red::Configuration.new:
        :base-path($*CWD),
        :drivers[$driver],
    ;

    # 1. Ensure the migration tracking table exists
    ensure-migration-table($config);

    # 2. Read current version from DB
    my $db-version = get-applied-version($config);

    # 3. Find all pending up.sql files
    my @pending;
    for $config.version-storage-path.dir(:test(*.d)).sort(*.basename.Int) -> $dir {
        my $ver = $dir.basename.Int;
        next if $ver <= $db-version;
        my $up-file = $config.up-sql($driver, $ver);
        if $up-file.f {
            @pending.push: %(:$ver, :file($up-file));
        }
    }

    unless @pending {
        note "Database is up to date (version: $db-version)";
        return;
    }

    # 4. Apply each pending migration in a transaction
    for @pending -> %m {
        my $ver  = %m<ver>;
        my $file = %m<file>;
        note "Applying migration v$ver: { $file.relative($*CWD) }";

        get-RED-DB.execute: "BEGIN";
        for $file.lines -> $sql {
            my $trimmed = $sql.trim;
            next if $trimmed eq '' || $trimmed.starts-with('--');
            get-RED-DB.execute: $trimmed;
        }
        # Record the migration
        record-migration($config, $ver, $file.basename);
        get-RED-DB.execute: "COMMIT";
        note "  ✓ Migration v$ver applied successfully.";
        CATCH {
            default {
                note "  ✗ Migration v$ver FAILED: { .message }";
                get-RED-DB.execute: "ROLLBACK";
                die "Migration v$ver failed. Aborting.";
            }
        }
    }

    my $new-version = @pending.tail<ver>;
    note "Database migrated to version $new-version.";
}

#| Ensure the migration tracking table exists in the database.
sub ensure-migration-table(Red::Configuration $config) {
    # Create the tracking table if it doesn't exist
    my $sql;
    given get-RED-DB.^name {
        when /SQLite/ {
            $sql = q:to/SQL/;
                CREATE TABLE IF NOT EXISTS red_migrations (
                    version     INTEGER PRIMARY KEY,
                    name        TEXT NOT NULL,
                    applied_at  TEXT NOT NULL DEFAULT (datetime('now'))
                )
                SQL
        }
        when /Pg/ {
            $sql = q:to/SQL/;
                CREATE TABLE IF NOT EXISTS red_migrations (
                    version     INTEGER PRIMARY KEY,
                    name        TEXT NOT NULL,
                    applied_at  TIMESTAMP NOT NULL DEFAULT NOW()
                )
                SQL
        }
        default {
            note "Warning: unknown driver for migration tracking table, skipping.";
            return;
        }
    }
    get-RED-DB.execute: $sql;
}

#| Get the currently applied migration version from the DB.
sub get-applied-version(Red::Configuration $config --> UInt) {
    my $result = get-RED-DB.prepare(
        "SELECT MAX(version) as max_ver FROM red_migrations"
    ).head.execute;
    try { $result.row<max_ver> // 0 } // 0
}

#| Record that a migration was applied.
sub record-migration(Red::Configuration $config, UInt $version, Str $name) {
    my $sql;
    given get-RED-DB.^name {
        when /SQLite/ {
            $sql = "INSERT INTO red_migrations (version, name) VALUES (?, ?)";
        }
        when /Pg/ {
            $sql = "INSERT INTO red_migrations (version, name) VALUES (\$1, \$2)";
        }
        default { return }
    }
    get-RED-DB.execute: $sql, $version, $name;
}
