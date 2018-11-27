use Red::AST;
use Red::AST::Value;
unit class Red::AST::Case does Red::AST;

has Red::AST $.case;
has Red::AST %.when{Red::AST};
has Red::AST $.else;

method new(Red::AST :$case, Red::AST :%when, Red::AST :$else) {
    do if %when.first: { .key ~~ Red::AST::Value and  .key.value === True } -> $_ {
        .value.self
    } else {
        my Red::AST %filteredWhen{Red::AST} = %when.grep: { .key !~~ Red::AST::Value or .key.value !=== False };
        die "No conditions passed to CASE/WHEN" unless %filteredWhen;
        nextwith :$case, :when(%filteredWhen), :$else
    }
}

method args {
    $!case, |%!when.kv, $!else
}

method returns {
    #%!when.head.value.returns
}

method find-column-name {}
