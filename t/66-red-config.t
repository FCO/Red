#!/ust/bin/env raku

use Test;

use lib "examples/blog2";
use lib "t/lib";
use BlogConfig;

lives-ok {
    Schema.create;
    .^refresh.say for Post.^all.grep: *.author.name eq "Fernando"
},  "Schema, Post and ops were exported";

done-testing
