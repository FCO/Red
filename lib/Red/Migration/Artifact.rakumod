use Configuration;
use Red::Cli::Table;
use Red::Cli::Column;
use X::Red::Migration;
=head2 Red::Migration::Artifact

module Red::Migration::Artifact {

    #| Typed configuration root for a version manifest, including ancestry and driver metadata.
    class Manifest does Configuration::Node {
        has Int $.format = 2;
        has Str $.id is required;
        has Str $.name is required;
        has Str $.predecessor = '';
        has %.drivers;
        has Str $.logical-checksum;
        has Str $.replaces;
        has Bool $.imported;
        has %.origin;
        has Str $.state;
        has Str $.before-checksum;
        has Str $.data-checksum;
        # Read old manifests only far enough to issue the format-3 rejection.
        has %.population;

        #| Return defined manifest fields as a metadata hash, including identity, ancestry and
        #| integrity fingerprints. Retain legacy population metadata only for format rejection.
        method artifact-data(--> Hash) {
            my %data;
            for <format id name predecessor drivers logical-checksum replaces state before-checksum data-checksum imported> -> $key {
                %data{$key} = self."$key"() if self."$key"().defined;
            }
            %data<origin> = %!origin if %!origin;
            %data<population> = %!population if %!population;
            %data
        }
    }
    #| Typed configuration root for the portable structural changes recorded by a version.
    class Operations does Configuration::Node {
        has @.operations;
        #| Return the ordered portable schema changes used to validate and rebase this version.
        method artifact-data(--> Array) { @!operations.Array }
    }
    #| Typed configuration root for explicitly supplied SQL and its inverse policy for one driver.
    class Overrides does Configuration::Node {
        has Bool $.manual = False;
        has Str $.down-state is required;
        has Str $.reason = '';
        #| Return the manual SQL selection, inverse availability and review reason for one driver.
        method artifact-data(--> Hash) {
            %(manual => $!manual, down-state => $!down-state, reason => $!reason)
        }
    }
    #| Typed configuration root that reconstructs historical Red::Cli::Table objects.
    class Schema does Configuration::Node {
        has Red::Cli::Table @.tables;
        #| Return the typed historical table objects constructed by the schema configuration.
        method artifact-data(--> Array) { @!tables.Array }
    }

    # Each artifact has a local builder. Loading one must never replace the project's
    # Configuration singleton or its test overrides.
    #| Create isolated typed configuration builders for an artifact kind. Artifact loading must not
    #| replace the application Configuration singleton.
    our sub builders(Str $kind) {
        my $root = do given $kind {
            when 'manifest' { Manifest }
            when 'operations' { Operations }
            when 'schema' { Schema }
            when 'overrides' { Overrides }
            default {
                X::Red::Migration.new(:reason("Unknown migration artifact kind: $kind")).throw;
            }
        };
        my &builder = Configuration.new(:$root, :file('artifact.rakuconf')).generate-config;
        Map.new(
            '&config' => -> &block { builder(&block).artifact-data },
            '&table' => Configuration.new(:root(Red::Cli::Table), :file('artifact.rakuconf')).generate-config,
            '&column' => Configuration.new(:root(Red::Cli::Column), :file('artifact.rakuconf')).generate-config)
    }

    #| Serialize nested metadata deterministically as readable Raku expressions. Itemize hashes
    #| inside positional collections so their pairs do not flatten into the surrounding array.
    sub literal($value, Int $depth = 0, Bool :$itemize = False --> Str) is export {
        my $indent = '    ' x $depth;
        my $child = '    ' x ($depth + 1);
        given $value {
            when Associative {
                return ($itemize ?? '$(%())' !! '%()') unless .elems;
                my $source = '%(' ~ "\n" ~ .keys.sort.map({
                    $child ~ .raku ~ ' => ' ~ literal($value{$_}, $depth + 1) ~ ','
                }).join("\n") ~ "\n$indent)";
                $itemize ?? '$(' ~ $source ~ ')' !! $source
            }
            when Positional {
                return '[]' unless .elems;
                "[\n" ~ .list.map({ $child ~ literal($_, $depth + 1, :itemize) ~ ',' }).join("\n")
                    ~ "\n$indent]"
            }
            default { .raku }
        }
    }

    #| Generate a trusted executable config artifact for a manifest, operations or driver overrides,
    #| with deterministic key ordering and typed builders.
    sub artifact-source(Str $kind, $data --> Str) is export {
        X::Red::Migration.new(:reason("Unsupported migration artifact serialization: $kind")).throw
            unless $kind eq any(<manifest operations overrides>);
        my @assignments = $kind eq any(<manifest overrides>)
            ?? $data.keys.sort.map({ '    .' ~ $_ ~ ' = ' ~ literal($data{$_}, 1) ~ ';' })
            !! ('    .operations = ' ~ literal($data, 1) ~ ';',);
        "use Red::Migration::Artifact '$kind';\n\nconfig \{\n"
            ~ @assignments.join("\n") ~ "\n}\n"
    }
}

sub EXPORT(Str $kind = '') {
    $kind ?? Red::Migration::Artifact::builders($kind) !! Map.new
}
