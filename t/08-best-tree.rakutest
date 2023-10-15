use Red;
use Test;

class X::Tree::ExistsInTheSameArea is Exception {
    has Rat $.longitude;
    has Rat $.latitude;

    method message { "A tree on ($!longitude, $!latitude) was already suggested" }
}

model BestTree::Store is table<tree> {
    has Rat     $.latitude      is id;
    has Rat     $.longitude     is id;
    has Rat     $.height        is column;
    has Str     $.description   is column;

    ::?CLASS.^add-unique-constraint: { .latitude, .longitude };

    method all-trees {
        self.^all.sort: -*.height
    }

    method find-tree(Rat() $longitude, Rat() $latitude) {
        self.^find: :$longitude, :$latitude
    }

    method suggest-tree(Rat() $longitude, Rat() $latitude, Rat() $height, Str $description) {
        CATCH {
            when X::Red::Driver::Mapped::Unique {
                die X::Tree::ExistsInTheSameArea.new: :$longitude, :$latitude
            }
        }
        self.^create: :$longitude, :$latitude, :$height, :$description
    }
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

lives-ok { schema(BestTree::Store).drop.create }

is BestTree::Store.all-trees, ();
is-deeply BestTree::Store.find-tree(1.1, 2.1), Nil;
my $tree1 = BestTree::Store.suggest-tree: 1.1, 2.1, 5.1, "bla";
isa-ok $tree1, BestTree::Store;
is-deeply $tree1, BestTree::Store.find-tree(1.1, 2.1);
is-deeply [$tree1], @ = BestTree::Store.all-trees;
throws-like { BestTree::Store.suggest-tree: 1.1, 2.1, 6.1, "ble" }, X::Tree::ExistsInTheSameArea;
my $tree2 = BestTree::Store.suggest-tree: 1.2, 2.1, 6.1, "bli";
is-deeply $tree1, BestTree::Store.find-tree(1.1, 2.1);
is-deeply $tree2, BestTree::Store.find-tree(1.2, 2.1);
is-deeply [$tree2, $tree1], @ = BestTree::Store.all-trees;
my $tree3 = BestTree::Store.suggest-tree: 1.3, 2.2, 4.1, "blo";
is-deeply $tree1, BestTree::Store.find-tree(1.1, 2.1);
is-deeply $tree2, BestTree::Store.find-tree(1.2, 2.1);
is-deeply $tree3, BestTree::Store.find-tree(1.3, 2.2);
is-deeply [$tree2, $tree1, $tree3], @ = BestTree::Store.all-trees;
throws-like { BestTree::Store.suggest-tree: 1.3, 2.2, 15, "blu" }, X::Tree::ExistsInTheSameArea;

done-testing;
