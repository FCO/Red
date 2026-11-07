use Red;
use Red::Runtime::Configuration;

my %models = runtime-settings().model-types.map({ .^name => $_ }).Hash;
%models<Project>.^populate(:rows([
    { id => 1, name => 'Website' },
    { id => 2, name => 'Mobile app' },
    { id => 3, name => 'Internal tools' },
]));
True;
