use Red::AST;
unit role Red::AST::Infix does Red::AST;

has         $.left  is required;
has         $.right is required;
has Bool    $.bind-left  = False;
has Bool    $.bind-right = False;

method op { ... }

method args {
    $!bind-left  ?? * !! $!left,
    $!bind-right ?? * !! $!right
}

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

method bind { |$!left xx $!bind-left, |$!right xx $!bind-right }

method gist { "{$!left}{$.op}{$!right}" }
