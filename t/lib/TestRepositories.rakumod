# zef stages dependencies before installing them. Child Raku processes need
# the same repositories, including inst# path specs for staged distributions.
unit module TestRepositories;

sub inherit-test-repositories() is export {
    my @libraries = $*REPO.repo-chain.grep({
        $_ ~~ CompUnit::Repository::FileSystem
            || $_ ~~ CompUnit::Repository::Installation
    }).map(*.path-spec);
    %*ENV<RAKULIB> = (|@libraries, |(%*ENV<RAKULIB> // '').split(','))
        .grep(*.chars).unique.join(',');
}
