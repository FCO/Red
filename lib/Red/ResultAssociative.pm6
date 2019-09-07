use Red::AST;
use Red::Model;
use Red::AST::Infixes;
use Red::AST::Value;
unit role Red::ResultAssociative[Red::Model $of, Red::AST $key-of] does Associative;

has Red::AST    $!key-of = $key-of;
has             $.rs is required;

method of     { $of }
method key-of { $!key-of.returns }

method keys {
    $!rs.create-map: $key-of, :group($key-of)
}

method AT-KEY($key) {
    $!rs.grep: { Red::AST::Eq.new: $!key-of, ast-value($key), :bind-right }
}

method iterator {
    gather for $.keys.Seq.grep: { .DEFINITE } { take $_ => self.AT-KEY: $_ }.iterator
}

method gist {
    "\{{self.map({ "{.key} => {.value.gist}" }).join: ", "}\}"
}
