use Test;
use Red:api<2>;

model Mmm {
    has $!id    is serial;
    has $.value is column;
}

red-defaults default => database "SQLite";

lives-ok { Mmm.^create-table }
dies-ok  { Mmm.^create-table }
lives-ok { Mmm.^create-table: :if-not-exists }
lives-ok { Mmm.^create-table: :unless-exists }

done-testing;
