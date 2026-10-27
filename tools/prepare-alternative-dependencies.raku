use Zef::CLI;

# Download and stage sources, without installing Rakudo precompilation artifacts.
# These modules come from each compiler; libpq is installed by the CI apt step.
MAIN('install', '.', :force-install, :contained, :dry, :!test,
    :test-depends, :deps-only,
    :exclude(['Test', 'NativeCall', 'pq:ver<5>:from<native>']));
