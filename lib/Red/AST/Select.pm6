use Red::AST;
use Red::Model;
use Red::AST::Union;
use Red::AST::Intersect;
use Red::AST::Minus;
use Red::AST::Comment;
unit class Red::AST::Select does Red::AST;

has Mu:U                $.of;
has Red::AST            @.fields;
has Red::AST            $.filter;
has Red::AST            @.order;
has Int                 $.limit;
has Int                 $.offset;
has Red::AST            @.group;
has                     @.table-list;
has Red::AST::Comment   @.comments;
has Bool                $.sub-select;

method returns { Red::Model }

method args { $!sub-select ?? () !! ( $!of, $!filter, |@!order ) }

method gist {
    do if $!sub-select {
        "{ self.^name }:\n" ~ [$!of, $!filter, |@!order].map(*.gist).join("\n").indent: 4
    } else {
        self.Red::AST::gist()
    }
}

method tables(::?CLASS:D:) {
    |(|@!table-list, |(.tables with $!filter), callsame).grep(-> \v { v !=:= Nil }).unique
}
method find-column-name {}

method union($sel) {
    my $union = Red::AST::Union.new;
    $union.union: self;
    $union.union: $sel;
    $union
}

method intersect($sel) {
    my $union = Red::AST::Intersect.new;
    $union.intersect: self;
    $union.intersect: $sel;
    $union
}

method minus($sel) {
    my $union = Red::AST::Minus.new;
    $union.minus: self;
    $union.minus: $sel;
    $union
}

method as-sub-select {
    $!sub-select = True;
    self;
}
