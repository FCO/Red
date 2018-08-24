use Red::AST;
unit class Red::FakeSeq;
also does Sequence;
also does Positional;

has Mu:U        $.of;
has Red::AST    $.ast;

method iterator {
    [$!of].iterator
}

method grep(&func) {
    my $ast = $!ast.add: func $!of;
    self.WHAT.new: :$!of, :$ast
}
