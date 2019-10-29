use Red::AST;
use Red::Model;
use Red::AST::Infixes;
use Red::AST::Value;

=head2 Red::ResultSeqSeq

unit class Red::ResultSeqSeq does Positional;

has     $.rs    is required;
has Int $.size  is required = 1;

#| run SQL query to get how many elements
method elems {
    ($!rs.elems / $!size).ceiling
}

#| return a ResultSeq for that index
method AT-POS($key) {
    $!rs.from($key * $!size).head: $!size
}

method iterator {
    gather for 0 .. $.elems { take self.AT-POS: $_ }.iterator
}

method gist {
    "[{self.map({ "{ .gist }" }).join: ", "}]"
}
