use Red::AST;
use Red::Model;
use Red::AST::Infixes;
use Red::AST::Value;
unit role Red::ResultAssociative[Red::Model $of, Red::AST $key-of] does Associative;

has Red::AST    $!key-of = $key-of;
has             $.rs is required;

#| type of the value
method of     { $of }

#| type of the key
method key-of { $!key-of.returns }

#| return a list of keys
#| run a SQL query to get it
method keys {
    $!rs.create-map: $key-of, :group($key-of)
}

#| return a ResultSeq for the given key
method AT-KEY($key) {
    $!rs.grep: { Red::AST::Eq.new: $!key-of, ast-value($key), :bind-right }
}

method iterator {
    gather for $.keys.Seq.grep: { .DEFINITE } { take $_ => self.AT-KEY: $_ }.iterator
}

method gist {
    "\{{self.map({ "{.key} => {.value.gist}" }).join: ", "}\}"
}
