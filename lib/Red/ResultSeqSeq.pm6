use Red::AST;
use Red::Model;
use Red::AST::Infixes;
use Red::AST::Value;
unit class Red::ResultSeqSeq does Positional;

has     $.rs    is required;
has Int $.size  is required = 1;

method elems {
    ($!rs.elems / $!size).ceiling
}

method AT-POS($key) {
    $!rs.from($key * $!size).head: $!size
}

method iterator {
    gather for 0 .. $.elems { take self.AT-POS: $_ }.iterator
}

method gist {
    "[{self.map({ "{ .gist }" }).join: ", "}]"
}