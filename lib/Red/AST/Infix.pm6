use Red::AST::Operator;
unit role Red::AST::Infix does Red::AST::Operator;

has Red::AST $.left  is required;
has Red::AST $.right is required;
has Bool     $.bind-left  = False;
has Bool     $.bind-right = False;

#method transpose(&func) {
#    $!left.transpose: &func;
#    $!right.transpose: &func;
#    func self
#}

proto method new(Red::AST $left, Red::AST $right, |) {*}

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
