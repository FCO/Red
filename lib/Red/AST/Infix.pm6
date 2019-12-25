use Red::AST::Operator;
use Red::AST::Unary;

#| Base role to infix operators
unit role Red::AST::Infix does Red::AST::Operator;

has Red::AST $.left  is required;
has Red::AST $.right is required;
has Bool     $.bind-left  = False;
has Bool     $.bind-right = False;

#method gist { "$!left.gist() $.op $!right.gist()" }

proto method new($left, $right, |) {*}

multi method new($left, $right, Bool() :$bind-left = False, Bool() :$bind-right = False, Str() :$cast!) {
    ::?CLASS.new:
        $left  ~~ ::("Red::Column") ?? $left.cast($cast)  !! $left,
        $right ~~ ::("Red::Column") ?? $right.cast($cast) !! $right,
        :$bind-left,
        :$bind-right
}

multi method new($left, $right, Bool :$bind-left = False, Bool :$bind-right = False) {
    ::?CLASS.Mu::new: :$left, :$right, :$bind-left, :$bind-right
}

method args { $!left, $!right }
method not { Red::AST::Not.new: self }
method find-column-name { ($_ with $.left.find-column-name), ($_ with $.right.find-column-name) }
