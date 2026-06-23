#| Manages migration paths, versions, and model snapshots for Red migrations.
class Red::Configuration {

#| Base project directory (where META6.json lives)
has IO() $.base-path              = $*CWD;
#| Root directory for all migration artifacts
has IO() $.migration-base-path    = $!base-path.add: "migrations";
#| Where model snapshots are stored (versioned copies of .rakumod files)
has IO() $.model-storage-path     = $!migration-base-path.add: "models";
#| Where migration version directories live (each version gets a subdir)
has IO() $.version-storage-path   = $!migration-base-path.add: "versions";
#| Where SQL migration files are stored (per driver)
has IO() $.sql-storage-path       = $!migration-base-path.add: "sql";
#| Subdirectory name for SQL files within each version
has Str  $.sql-subdir             = "sql";
#| The current migration version (read from DB or tracking table)
has UInt $.current-version is rw  = 0;
#| Supported database drivers (used to generate driver-specific SQL)
has Str  @.drivers                = <SQLite Pg>;

#| Resolve the version directory for a given version number
method version-dir(UInt $version --> IO::Path) {
    $!version-storage-path.add: $version.Str
}

#| Resolve the SQL directory for a given driver (uses current version)
method sql-dir(Str $driver --> IO::Path) {
    self.version-dir($!current-version).add: $!sql-subdir, $driver
}

#| Resolve the SQL directory for a given version and driver
method sql-dir-for(Str $driver, UInt $version --> IO::Path) {
    self.version-dir($version).add: $!sql-subdir, $driver
}

#| Resolve the global SQL storage path for a driver
method global-sql-dir(Str $driver --> IO::Path) {
    $!sql-storage-path.add: $driver
}

#| Path to the up.sql file for a given driver and version
method up-sql(Str $driver, UInt $version --> IO::Path) {
    self.sql-dir-for($driver, $version).add: "up.sql"
}

#| Path to the down.sql file for a given driver and version
method down-sql(Str $driver, UInt $version --> IO::Path) {
    self.sql-dir-for($driver, $version).add: "down.sql"
}

#| Path to the global up.sql for a driver (non-versioned, apply-all style)
method global-up-sql(Str $driver --> IO::Path) {
    self.global-sql-dir($driver).add: "up.sql"
}

#| Path to the global down.sql for a driver
method global-down-sql(Str $driver --> IO::Path) {
    self.global-sql-dir($driver).add: "down.sql"
}

#| Store a snapshot of a model file into the versioned model storage.
#| Uses a microsecond timestamp + random suffix for unique, ordered filenames.
#| Returns the path where it was stored.
method store-model(IO() $source-file, Str $model-name --> IO::Path) {
    $!model-storage-path.mkdir: :p;
    my $suffix = (now * 1_000_000).Int ~ '-' ~ (^0xFFFF).pick.fmt('%04x');
    my $dest = $!model-storage-path.add: "{ $model-name }-{ $suffix }.rakumod";
    $source-file.copy: $dest;
    $dest
}

#| Store version info for a migration step.
method store-version(UInt $version, Str $description = "") {
    my $dir = self.version-dir: $version;
    $dir.mkdir;
    $dir.add("info.txt").spurt: "version: $version\ncreated: { DateTime.now }\ndescription: $description\n";
}

#| Ensure all required directories exist.
method ensure-dirs() {
    .mkdir for $!migration-base-path, $!model-storage-path,
               $!version-storage-path, $!sql-storage-path;
    self
}
}