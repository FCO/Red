use Red::AST;
use Red::AST::Infixes;
use Red::AST::Value;

unit role Red::AST::Optimizer::Case;

my subset AstFalse of Red::AST::Value where { .value === False };
my subset AstTrue  of Red::AST::Value where { .value === True  };

multi method optimize(
        Red::AST:U :$case,
        Red::AST   :%when! where {
            .elems == 1 && .values.head.?type ~~ Positional
        },
        Red::AST:U :else($),
) {
    %when.values.head.get-value<>
}

multi method optimize(
    Red::AST:U :$case,
    Red::AST   :%when! where { .elems >= 1 },
    Red::AST   :$else! where { [eqv] |%when.values, $else },
) {
    $else
}

multi method optimize(
    Red::AST:D :$case,
    Red::AST   :%when! where {
        .first: { .key ~~ AstTrue }
    },
    Red::AST :$else,
) {
    %when.first({ .key ~~ AstTrue }).value.self
}

multi method optimize(
    Red::AST:U :$case,
    Red::AST   :%when! where {
        .elems == 1 and not .keys.head.defined
    },
    Red::AST:U :else($),
) {
    %when.values.head
}

multi method optimize(
    Red::AST:U :$case,
    Red::AST :%when! where {
        .elems == 2
        && Red::AST::AND.new(|.keys) ~~ AstTrue
    },
    Red::AST:U :else($),
) {
    my $to-remove = %when.keys.first(Red::AST::So) // %when.keys.head;

    my $else = %when{$to-remove}:delete;

    my \ret = self.optimize: :$case, :%when, :$else;
    return ret if ret.DEFINITE && ret ~~ Red::AST;

    self.bless: :$else, :%when
}

multi method optimize(Red::AST :$case, Red::AST :%when, Red::AST :$else, UInt :$c where { $_ < 1 } = 0) {
    my Red::AST %filteredWhen{Red::AST} = %when.grep: { .key !~~ AstFalse };
    die "No conditions passed to CASE/WHEN" unless %filteredWhen;
    my \ret = self.optimize: :$case, :when(%filteredWhen), :$else, :c($c + 1);
    return ret if ret.DEFINITE && ret !~~ Empty;
    self.bless: :$case, :when(%filteredWhen), :$else
}

multi method optimize(:case($), :when(%), :else($)) { Nil }
