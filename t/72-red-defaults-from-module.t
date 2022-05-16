use Red;
use lib "t/lib";

use Schema;
use Test;

lives-ok {
  bla-schema.drop.create;

  ok Bla.^create: :value<test1>;
  ok Bla.^create: :value<test2>;

  is Bla.^all.elems, 2;
}

my $proms = start {
  react {
    whenever Supply.from-list: ^3 {
      lives-ok {
        bla-schema.drop.create;

        ok Bla.^create: :value<test1>;
        ok Bla.^create: :value<test2>;

        is Bla.^all.elems, 2;
      }
    }
  }
}

await $proms;

done-testing;
