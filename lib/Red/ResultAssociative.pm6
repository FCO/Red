use Red::AST;
use Red::Model;
use Red::AST::Infixes;
use Red::AST::Value;
use Red::AST::Function;

=head2 Red::ResultAssociative

#| Lazy Associative class from Red queries (.classify)
unit role Red::ResultAssociative[$of, Red::AST $key-of] does Associative;

has Red::AST    $!key-of = $key-of;
has             $.rs is required;

#| type of the value
method of     { $of }

#| type of the key
method key-of { $!key-of.returns }

#| return a list of keys
#| run a SQL query to get it
method keys {
    $!rs.map({ Red::AST::Function.new(:func<DISTINCT>, :args[$key-of], :returns(Int)) })
}

#| Run query to get the number of elements
method elems {
    $!rs.map({
        Red::AST::Function.new(:func<COUNT> :args[
            Red::AST::Function.new(:func<DISTINCT>, :args[$key-of], :returns(Int))
        ])
    }).head
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

#| Run query to create a Bag
method Bag {
    my $rs = $!rs.map({ ($key-of, Red::AST::Function.new(:func<COUNT>, :args[ast-value("*"),], :returns(Int))) });
    $rs.group = $!key-of;
    $rs.Seq.map({ .[0] => .[1] }).Bag
}

#| Run query to create a Set
method Set {
    my $rs = $!rs.map({ Red::AST::Function.new(:func<DISTINCT>, :args[$key-of], :returns(Int)) });
    $rs.Seq.Set
}
