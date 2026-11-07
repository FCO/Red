use Red;
use Red::Runtime::Configuration;

my %models = runtime-settings().model-types.map({ .^name => $_ }).Hash;
%models<Task>.^populate(:rows([
    { id => 1, title => 'Build homepage', project-id => 1 },
    { id => 2, title => 'Add contact form', project-id => 1 },
    { id => 3, title => 'Design login screen', project-id => 2 },
    { id => 4, title => 'Import customer data', project-id => 3 },
]));
True;
