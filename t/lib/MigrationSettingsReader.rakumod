use Red::Migration::Configuration;
unit module MigrationSettingsReader;
sub read-migration-settings(IO() $file) is export {
    single-config-run(:$file)
}
