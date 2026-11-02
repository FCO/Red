use Red;
use Configuration;
use X::Red::Migration;

=head2 Red::Migration::Configuration

class Red::Migration::Configuration does Configuration::Node {
    has @.models;
    has Str @.drivers = <SQLite>;
    has %.connections;
    has %.test-servers;
    has %.type-mappings;
    has IO() $.directory = 'migrations'.IO;

    #| Resolve configured model types or module names and return Red model type objects. Reject
    #| instances and values that are not Red models.
    method model-types(--> Array) {
        @!models.map(-> $entry {
            my $model = $entry;
            if $entry ~~ Str {
                require ::($entry);
                $model = ::($entry);
            }
            X::Red::Migration.new(:reason('Configured models must be Red model types or module names')).throw
                unless $model ~~ Red::Model && !$model.DEFINITE;
            $model
        }).Array
    }

    #| Load a trusted project configuration through the Configuration reader and require a
    #| Red::Migration::Configuration result.
    method load(::?CLASS:U: IO() $file --> ::?CLASS) {
        my %api = configuration-api();
        my $config = %api<&single-config-run>(:file($file.absolute.IO));
        X::Red::Migration.new(:reason('Configuration must return Red::Migration::Configuration')).throw
            unless $config ~~ self;
        $config
    }
}

# Keep Configuration's builder, reader and test overrides on the same API.
#| Initialize the migration Configuration root when needed and generate its builder and reader
#| exports without replacing an existing application configuration singleton.
sub configuration-api() {
    PROCESS::<$CONFIG-OBJECT> //= Configuration.new(
        :root(Red::Migration::Configuration), :file('red.rakuconf'));
    Configuration.generate-exports(Red::Migration::Configuration)
}

sub EXPORT { configuration-api() }

# Export-time initialization is not retained when an importing module is precompiled.
INIT { configuration-api() }
