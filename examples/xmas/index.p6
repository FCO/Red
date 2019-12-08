#!/usr/bin/env perl6

use Red;# <red-do>;

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

Child.^create: :name<Fernanda>, :address<there>, :asked-by-year[{:gift{:name<pokemon>}}];
Child.^create: :name<Sophia>,   :address<there>, :asked-by-year[{:gift{:name<doll>}}];

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

multi MAIN("asked-by", Str $child) {
    .say for Child.^find(:name($child)).asked.map: *.gift
}

multi MAIN("num-child-asked", Str $name) {
    with Gift.^find(:$name) {
        say .child-asked-on-year.elems
    } else {
        die "Gift '$name' not found"
    }
}

multi MAIN("num-of-gifts") {
#    my $*RED-DEBUG = True;
    say ChildAskedOnYear.^all.map(*.gift.name).Bag
}

multi MAIN("add-child", Str $name, Str :$address!) {
    say Child.^create: :$name, :$address
}

multi MAIN("list-children", :$starting-with, :$ending-with, :$containing) {
    my $rs = Child.^all;
    $rs .= grep: *.name.starts-with: $_ with $starting-with;
    $rs .= grep: *.name.ends-with:   $_ with $ending-with;
    $rs .= grep: *.name.contains:    $_ with $containing;
    .say for $rs.sort: *.name
}


multi MAIN("list-gifts", :$starting-with, :$ending-with, :$containing) {
    my $rs = Gift.^all;
    $rs .= grep: *.name.starts-with: $_ with $starting-with;
    $rs .= grep: *.name.ends-with:   $_ with $ending-with;
    $rs .= grep: *.name.contains:    $_ with $containing;
    .say for $rs.sort: *.name
}