use Test;
use Red;

plan 1;

my $*RED-DB = database "Mock";

model M is table<mmm> {
    has Int     $.a is column;
    has Bool    $.b is column;
}

M.^create-table;

$*RED-DB.die-on-unexpected;

$*RED-DB.when: :once, Q[select case when ( b == 0 or b is null ) then a else a end as "data_1" from mmm], :return[{:1data_1}, {:2data_1}, {:3data_1}];

M.^all.map({ .b if .b; .a }).Seq;

$*RED-DB.when: :once, rx[select <.ws> [ "mmm."[a|b] <.ws> as <.ws> \"data_\d\" ] ** 3 % [<.ws>","<.ws>] <.ws> from <.ws> mmm], :return[{:1data_1}, {:2data_1}, {:3data_1}];

M.^all.map({ .a, .b, .a }).Seq;

#$*RED-DB.when: #`(:twice) :once, Q[SELECT mmm.a as "data" FROM mmm WHERE not (b == 0 OR b IS NULL)], :return[{:1data}, {:2data}, {:3data}];
#
#M.^all.map({ .a if .b }).Seq;
#
##M.^all.map({ next unless .b; .a }).Seq; # TODO: review next

$*RED-DB.verify;
