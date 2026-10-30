use Red;
use X::Red::Migration;
unit class Red::Migration::Configuration;

has @.models;
has Str @.drivers = <SQLite>;
has %.connections;
has IO() $.directory = 'migrations'.IO;

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

method load(::?CLASS:U: IO() $file --> ::?CLASS) {
    use MONKEY-SEE-NO-EVAL;
    my $config = EVALFILE $file.absolute;
    X::Red::Migration.new(:reason('Configuration must return Red::Migration::Configuration')).throw
        unless $config ~~ self;
    $config
}
