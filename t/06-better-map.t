use Test;
use Red;

plan 1;

my $*RED-DB = database "Mock";
$*RED-DB.die-on-unexpected;

model M is table<mmm> {
    has Int     $.a is column;
    has Bool    $.b is column;
}

$*RED-DB.when: :once,  Q[create table mmm ( b integer null , a integer null )], :return[];
$*RED-DB.when: :twice, Q[SELECT mmm.a as "data" FROM mmm WHERE not (b == 0 OR b IS NULL)], :return[{:1data}, {:2data}, {:3data}];

M.^create-table;

M.^all.map({ .a if .b }).Seq;

M.^all.map({ next unless .b; .a }).Seq;

$*RED-DB.verify;
