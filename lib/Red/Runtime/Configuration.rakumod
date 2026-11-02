use X::Red::Exceptions;
use Red::Driver;

unit module Red::Runtime::Configuration;

my Lock $lock .= new;
my %contexts;

#| Read project settings lazily, respecting Configuration's dynamic test overrides. Keep one
#| context per thread and configuration reader; importing Red never evaluates a project file.
sub runtime-context() {
    return Nil if CALLERS::<$*RED-CONFIG-LOADING>;
    return Nil unless $*CONFIG-OBJECT.defined || 'red.rakuconf'.IO.f;
    my $*RED-CONFIG-LOADING = True;
    require ::('Red::Migration::Configuration');
    my $reader = $*CONFIG-OBJECT;
    return Nil unless $reader.root === ::('Red::Migration::Configuration');
    return Nil unless $reader.block.defined || ($reader.file.defined && $reader.file.f);
    my $key = $*THREAD.id.Str;
    my $source = $reader.file.defined ?? $reader.file.absolute.Str !! '';
    return $lock.protect: {
        my $context = %contexts{$key};
        unless $context.defined && $context<reader> === $reader && $context<source> eq $source {
            my $settings = $reader.single-run;
            X::Red::Configuration.new(:reason(
                'Red configuration must return Red::Migration::Configuration')).throw
                unless $settings ~~ ::('Red::Migration::Configuration');
            $context = %( :$reader, :$source, :$settings );
            %contexts{$key} = $context;
        }
        $context
    }
    CATCH {
        when X::Red::Configuration { .rethrow }
        default {
            X::Red::Configuration.new(:reason("Cannot load Red configuration: {.message}")).throw
        }
    }
}

#| Return configured settings without opening a database, or Nil when none are available.
sub runtime-settings() is export {
    my $context = runtime-context();
    $context.defined ?? $context<settings> !! Nil
}

#| Resolve the default connection only on demand. Reuse factories' results per thread until the
#| Configuration reader is replaced, including by set-config.
sub runtime-database() is export {
    my $context = runtime-context();
    return Nil unless $context.defined;
    return $context<driver> if $context<driver>:exists;
    X::Red::Configuration.new(:reason('Recursive default connection factory')).throw
        if CALLERS::<$*RED-CONFIG-CONNECTING>;
    my $*RED-CONFIG-CONNECTING = True;
    my $driver = $context<settings>.connections<default>;
    $driver = $driver() if $driver ~~ Callable;
    X::Red::Configuration.new(:reason(
        'Configure .connections<default> with a Red::Driver or a factory returning one')).throw
        unless $driver ~~ Red::Driver:D;
    $context<driver> = $driver;
    $driver
}
