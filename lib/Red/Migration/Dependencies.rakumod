use JSON::Fast;
use Red::Migration::Bundle;
use X::Red::Migration;

unit module Red::Migration::Dependencies;

sub reject(Str $reason) {
    X::Red::Migration.new(:$reason).throw
}

# Parse dependency qualifiers as data, never as Raku expressions.
sub dependency-spec($entry --> CompUnit::DependencySpecification) is export {
    if $entry ~~ Associative {
        reject('Dependency requires a name') unless $entry<name> ~~ Str;
        return CompUnit::DependencySpecification.new(
            :short-name($entry<name>), :auth-matcher($entry<auth>),
            :version-matcher($entry<ver> // $entry<version>), :api-matcher($entry<api>));
    }
    reject('Invalid dependency specification') unless $entry ~~ Str;
    my $name = $entry;
    my %qualifiers;
    while $name ~~ / ':' (auth|ver|api|from) '<' (<-[<>]>*) '>' $ / {
        %qualifiers{~$0} = ~$1;
        $name = $name.substr(0, $/.from);
    }
    reject("Invalid dependency name: $name") unless $name ~~ /^ <[A..Za..z0..9_-]>+ [ '::' <[A..Za..z0..9_-]>+ ]* $/;
    CompUnit::DependencySpecification.new(:short-name($name),
        :auth-matcher(%qualifiers<auth>), :version-matcher(%qualifiers<ver>),
        :api-matcher(%qualifiers<api>), :from(%qualifiers<from> // 'Raku'))
}

sub runtime-dependencies($depends --> List) {
    my $runtime = $depends ~~ Associative ?? ($depends<runtime> // []) !! $depends;
    ($runtime ~~ Associative ?? ($runtime<requires> // []) !! $runtime).list
}

sub resolve-distribution($repository, CompUnit::DependencySpecification $spec) {
    my $unit;
    {
        CATCH { default { $unit = Nil } }
        $unit = $repository.resolve($spec);
    }
    return $unit.distribution if $unit.defined;
    # A distribution name need not be one of the module names it provides.
    for $repository.repo-chain -> $repo {
        next unless $repo.^can('installed');
        my @matches = $repo.installed.grep(-> $distribution {
            my %meta := $distribution.meta;
            (%meta<name> // '') eq $spec.short-name
                && (%meta<auth> // '') ~~ $spec.auth-matcher
                && Version.new(%meta<version> // %meta<ver> // '0') ~~ $spec.version-matcher
                && Version.new(%meta<api> // '0') ~~ $spec.api-matcher
        }).sort({ Version.new(.meta<version> // .meta<ver> // '0') });
        return @matches.tail if @matches;
    }
    reject("Dependency is not installed: $spec")
}

# resolve returns metadata and an unloaded handle; it does not need/load the module.
sub discover-bundles(IO() $project = '.', :$repository = $*REPO --> Array) is export {
    my $meta = $project.add('META6.json');
    reject("Missing project metadata: $meta") unless $meta.f;
    my %root = from-json($meta.slurp);
    my %visited;
    my %versions;
    my @bundles;
    sub visit($entry) {
        my $spec = dependency-spec($entry);
        return if $spec.from ne any(<Raku Perl6>);
        my $distribution = resolve-distribution($repository, $spec);
        my %meta := $distribution.meta;
        my $identity = %meta<name> ~ ':auth<' ~ (%meta<auth> // '') ~ '>';
        my $version = (%meta<version> // %meta<ver> // '').Str;
        reject("Conflicting installed versions for $identity")
            if %versions{$identity}:exists && %versions{$identity} ne $version;
        %versions{$identity} = $version;
        return if %visited{$identity}++;
        my $depends = %meta<depends> // [];
        my @depends = runtime-dependencies($depends);
        visit($_) for @depends;
        my $bundle = Red::Migration::Bundle.load($distribution);
        @bundles.push($bundle) if $bundle.defined;
    }
    my $depends = %root<depends> // [];
    my @depends = runtime-dependencies($depends);
    visit($_) for @depends;
    @bundles.Array
}
