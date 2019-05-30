use Red;
use Red::ResultSeq;
use Red::ResultSeqSeq;
use Test;

model Bla { has UInt $.id is id }

my $*RED-DB = database "SQLite";

Bla.^create-table: :if-not-exists;

Bla.^create: :id($_) for ^347;

my @batches := Bla.^all.batch: 10;

isa-ok @batches, Red::ResultSeqSeq;

is @batches.elems, 35;

is-deeply @batches.head.map(*.id), eager ^10;
is-deeply @batches[1].grep(*.id %% 2).map(*.id), (10, 12, 14, 16, 18);
is @batches[2].first(*.id %% 2).id, 20;
is @batches[3].first(*.id %% 4).id, 32;

done-testing;
