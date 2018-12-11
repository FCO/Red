use Red::AST;
use Red::AST::Unary;
use Red::AST::Infixes;
use Red::AST::Value;
unit class Red::AST::Case does Red::AST;

has Red::AST $.case;
has Red::AST %.when{Red::AST};
has Red::AST $.else;

method new(Red::AST :$case, Red::AST :%when, Red::AST :$else is copy) {
    do if %when.first: { .key ~~ Red::AST::Value and .key.value === True } -> $_ {
        .value.self
    } elsif not $case.defined and %when == 1 and not %when.keys.head.defined {
        %when.values.head
    } elsif not $case.defined and %when == 2 and Red::AST::AND.new(|%when.keys) ~~ { $_ ~~ Red::AST::Value and .value === True } {
        my $to-remove = %when.keys.first(Red::AST::So) // %when.keys.head;
        nextwith :else(%when{$to-remove}:delete), :%when
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
