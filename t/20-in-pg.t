use Red;
use Test;

my $*RED-PG-TEST-DB = $_ with %*ENV<RED_PG_TEST_DB>;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-AST      = $_ with %*ENV<RED_DEBUG_AST>;

plan 2;
unless $*RED-PG-TEST-DB {
    "No RED_PG_TEST_DB initialized.".say;
    skip-rest 2;
}

model Category is table<test_category> {
    has Int $.id is serial;
    has Int $.parent_id is column{ :references{ Category.id }, :nullable, };
    has Str $.name is column;

    has Category $.parent is relationship{ .parent_id };
    has Category @.children is relationship{ .parent_id };
}

$GLOBAL::RED-DB = database "Pg", :dbname($*RED-PG-TEST-DB);

Category.^create-table;

my $parent = Category.^create: :name('xx');

for [1 .. 5] -> $x {
    Category.^create: :parent_id($parent.id), :name("child-$x");
}

# # This worked.
# (Category.^rs.grep: { .id (<) Category.^all.grep({ .id == 3 }).map({ .id }) } ).Seq.perl.say;

# # This doesn't.
# (Category.^rs.grep: { .id (<) $parent.children.map({ .id }) } ).Seq.perl.say;



# This worked in SQLite (But doesn't work with Pg driver.)
# my $*RED-DEBUG-AST = True;
my @seq = $parent.children.map({ .id }).Seq.sort;

is-deeply @seq, [Category.^rs.grep({ .id in @seq }).map(*.id).Seq.sort], "in with literal list for pg";
is-deeply @seq, [Category.^rs.grep({ .id (<) @seq }).map(*.id).Seq.sort], "in with literal list for pg (<) operator";

