use JSON::Fast;
use nqp;
use X::Red::Migration;

unit class Red::Migration::Bundle;

has Str $.identity is required;
has Str $.version = '';
has @.migrations;

sub reject(Str $reason) {
    X::Red::Migration.new(:$reason).throw
}

# Read only declared resources. Never evaluate dependency artifacts or load its modules.
method load(::?CLASS:U: Distribution:D $distribution --> ::?CLASS) {
    CATCH {
        when X::Red::Migration { .rethrow }
        default { reject("Cannot read migration bundle: {.message}") }
    }
    my %meta := $distribution.meta;
    my $index = 'red/migrations/index.json';
    my @resources = %meta<resources> ~~ Associative
        ?? %meta<resources>.keys !! (%meta<resources> // []).list;
    return Nil unless $index eq any(@resources);
    my &read = -> Str $name, Bool :$bin = False {
        reject("Undeclared migration resource: $name") unless $name eq any(@resources);
        reject("Invalid migration resource path: $name")
            if $name.starts-with('/') || $name.contains('\\')
                || $name.split('/').grep({ $_ eq any('', '.', '..') });
        my $handle = $distribution.content("resources/$name");
        LEAVE $handle.close if $handle.defined;
        if $distribution.^can('prefix') {
            my $relative = $handle.path.resolve.relative($distribution.prefix.resolve).IO;
            reject("Migration resource is outside its distribution: $name")
                if $relative.is-absolute || '..' eq any($relative.parts);
        }
        $handle.open unless $handle.opened;
        $handle.slurp(:$bin)
    };
    my %index = from-json(read($index));
    reject('Unsupported migration bundle format') unless (%index<format> // 0) == any(1, 2);
    reject('Migration bundle requires a migrations array') unless %index<migrations> ~~ Array;
    my %seen;
    my @migrations;
    for %index<migrations>.list -> $entry {
        reject('Invalid migration bundle entry') unless $entry ~~ Associative;
        my %migration = $entry.Hash;
        my $id = %migration<id> // '';
        reject("Invalid migration ID: $id") unless $id ~~ /^ <[0..9A..Z]> ** 26 $/;
        reject("Duplicate migration ID: $id") if %seen{$id}++;
        reject("Invalid migration predecessor: $id")
            unless (%migration<predecessor> // '') ~~ /^ [ <[0..9A..Z]> ** 26 ]? $/;
        reject("Migration $id requires SQL drivers") unless %migration<drivers> ~~ Associative;
        reject("Migration $id requires Raku execution") if %migration<data-checksum>:exists;
        my %artifacts;
        for (%migration<files> // {}).kv -> $name, $file {
            reject("Invalid artifact path: $name")
                if $name.starts-with('/') || $name.contains('\\')
                    || $name.split('/').grep({ $_ eq any('', '.', '..') });
            reject("Invalid artifact metadata: $name")
                unless $file ~~ Associative && $file<path> ~~ Str && $file<checksum> ~~ Str;
            my $source = read($file<path>, :bin(so $file<binary>));
            my $fingerprint = $source ~~ Blob ?? $source.decode('iso-8859-1') !! $source;
            reject("Migration resource checksum mismatch: {$file<path>}")
                unless nqp::sha1($fingerprint) eq $file<checksum>;
            %artifacts{$name} = $source;
        }
        my %sql;
        my %sql-files;
        for %migration<drivers>.kv -> $driver, $directions {
            reject("Unsupported migration driver: $driver") unless $driver eq any(<SQLite Pg MySQL DuckDB>);
            reject("Invalid SQL metadata: $id/$driver") unless $directions ~~ Associative;
            for <up down> -> $direction {
                my $definition = $directions{$direction};
                my @files = $definition ~~ Array ?? $definition.list !! ($definition,);
                my @sources;
                reject("Missing SQL resource: $id/$driver/$direction") unless @files;
                for @files -> $file {
                    reject("Missing SQL resource: $id/$driver/$direction")
                        unless $file ~~ Associative && $file<path> ~~ Str && $file<checksum> ~~ Str;
                    my $name = $file<name> // "$direction.sql";
                    reject("Invalid SQL filename: $name")
                        unless $name eq "$direction.sql"
                            || $name ~~ /^ $direction '/' \d ** 3..* '-' <[A..Za..z0..9_-]>+ '.sql' $/;
                    reject("Duplicate SQL filename: $name") if %sql-files{$driver}{$name}:exists;
                    my $source = read($file<path>);
                    reject("Migration resource checksum mismatch: {$file<path>}")
                        unless nqp::sha1($source) eq $file<checksum>;
                    if %artifacts{"$driver/$name"}:exists {
                        reject("SQL and artifact disagree: $driver/$name")
                            unless %artifacts{"$driver/$name"} eq $source;
                    }
                    %sql-files{$driver}{$name} = $source;
                    @sources.push($source);
                }
                %sql{$driver}{$direction} = @sources.join("\n");
            }
        }
        @migrations.push: %( |%migration, sql => %sql,
            sql-files => %sql-files, artifacts => %artifacts );
    }
    self.new(:identity(%meta<name> ~ ':auth<' ~ (%meta<auth> // '') ~ '>'),
        :version((%meta<version> // %meta<ver> // '').Str), :@migrations)
}
