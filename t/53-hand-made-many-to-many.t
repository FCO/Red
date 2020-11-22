use Test;
use Red:api<2>;

model AABB { ... }
model BB { ... }
model AA is table<aa> {
    has $.aa-id is serial;
    has $.aa-name is column;
    has AABB @.aa-bb is relationship{ .aa-id };
    method bb1 () {
        @!aa-bb.join-model: BB, *.bb-id == *.bb-id
    }
    method bb2 () {
        BB.^all.grep({
            .bb-id in @!aa-bb.map(*.bb-id)
        })
    }
}
model BB is table<bb> {
    has $.bb-id is serial;
    has $.bb-name is column;
}
model AABB is table<aabb> {
    has $.aa-id is column{
        :id
        :references(*.aa-id),
        :model-name<AA>,
    };
    has $.bb-id is column{
        :id,
        :references(*.bb-id),
        :model-name<BB>,
    };
}

my $*RED-FALLBACK       = $_ with %*ENV<RED_FALLBACK>;
my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my $*RED-DEBUG-AST      = $_ with %*ENV<RED_DEBUG_AST>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

schema(AA, BB, AABB).create;

my $aa1 = AA.^create: :aa-name<aa1>;
my $bb1 = BB.^create: :bb-name<bb1>;

AABB.^create: :aa-id($aa1.aa-id), :bb-id($bb1.bb-id);
lives-ok {
    is $aa1.bb1.map(*.bb-name).Seq, < bb1 >;
}
lives-ok {
    is $aa1.bb2.map(*.bb-name).Seq, < bb1 >;
}
#.say for $aa1.bb1.map: *.bb-name;

done-testing;
