#!/usr/bin/env perl6

use Red:api<2>;

use Child;
use Gift;
use ChildAskedOnYear;

my %*SUB-MAIN-OPTS =
        :named-anywhere,
;

red-defaults default => database "SQLite";

Child.^create-table: :unless-exists;
Gift.^create-table: :unless-exists;
ChildAskedOnYear.^create-table: :unless-exists;

for <doll ball car pokemon> -> $name {
    Gift.^create: :$name;
}

Child.^create: :name<Fernanda>, :country<UK>, :asked-by-year[{:gift{:name<pokemon>}}];
Child.^create: :name<Sophia>,   :country<UK>, :asked-by-year[{:gift{:name<doll>}}];

my $*RED-FALLBACK = False;

multi MAIN("ask", Str $name, Str :$child!) {
    my $gift = Gift.^find(:$name) // die "Gift '$name' not found";
    with Child.^find(:name($child)) {
        .asked.create: :$gift
    } else {
        die "Child '$child' not found"
    }
    MAIN("asked-by", $child)
}

multi MAIN("asked-by", Str $child, Int :$year) {
    .say for Child.^find(:name($child)).asked(|($_ with $year)).map: *.gift
}

multi MAIN("num-child-asked", Str $name) {
    with Gift.^find(:$name) {
        say .child-asked-on-year.elems
    } else {
        die "Gift '$name' not found"
    }
}

multi MAIN("num-of-gifts") {
    say ChildAskedOnYear.^all.map(*.gift.name).Bag
}

multi MAIN("add-child", Str $name, Str :$country!) {
    say Child.^create: :$name, :$country
}

multi MAIN("list-children", :$starting-with, :$ending-with, :$containing, :$country) {
    my $rs = Child.^all;
    $rs .= grep: *.name.starts-with: $_ with $starting-with;
    $rs .= grep: *.name.ends-with:   $_ with $ending-with;
    $rs .= grep: *.name.contains:    $_ with $containing;
    $rs .= grep: *.country eq        $_ with $country;
    .say for $rs.sort: *.name
}


multi MAIN("list-gifts", :$starting-with, :$ending-with, :$containing) {
    my $rs = Gift.^all;
    $rs .= grep: *.name.starts-with: $_ with $starting-with;
    $rs .= grep: *.name.ends-with:   $_ with $ending-with;
    $rs .= grep: *.name.contains:    $_ with $containing;
    .say for $rs.sort: *.name
}