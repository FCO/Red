use Red;
use Red::Runtime::Configuration;

my %models = runtime-settings().model-types.map({ .^name => $_ }).Hash;
%models<Comment>.^populate(:rows([
    { id => 1, body => 'Ready for review', task-id => 1 },
    { id => 2, body => 'Please check the mobile layout', task-id => 1 },
    { id => 3, body => 'Waiting for the design', task-id => 3 },
]));
True;
