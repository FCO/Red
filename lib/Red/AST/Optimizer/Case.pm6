use Red::AST;
use Red::AST::Infixes;
use Red::AST::Value;

unit role Red::AST::Optimizer::Case;

my subset AstFalse of Red::AST::Value where { .value === False };
my subset AstTrue  of Red::AST::Value where { .value === True  };

multi method optimize(
    Red::AST:U :$case,
    Red::AST :%when! where {
        .elems == 1 && .values.head.?type ~~ Positional
    },
    Red::AST :$else
) {
    %when.values.head.get-value<>
}

multi method optimize(
    Red::AST :$case,
    Red::AST :%when! where {
        .first: { .key ~~ AstTrue }
    },
    Red::AST :$else
) {
    %when.first({ .key ~~ AstTrue }).value.self
}

multi method optimize(
    Red::AST:U :$case,
    Red::AST :%when! where {
        .elems == 1 and not .keys.head.defined
    },
    Red::AST :$else
) {
    %when.values.head
}

multi method optimize(
    Red::AST:U :$case,
    Red::AST :%when! where {
        .elems == 2
        && Red::AST::AND.new(|.keys) ~~ AstTrue
    },
    Red::AST:U :$else
) {
    my $to-remove = %when.keys.first(Red::AST::So) // %when.keys.head;
    self.bless: :else(%when{$to-remove}:delete), :%when
}

multi method optimize(:$case, :%when, :$else) {
    my Red::AST %filteredWhen{Red::AST} = %when.grep: { .key !~~ AstFalse };
    die "No conditions passed to CASE/WHEN" unless %filteredWhen;
    self.bless: :$case, :when(%filteredWhen), :$else
}