use Red::AST;
unit class Red::FakeSeq;
also does Sequence;
also does Positional;

has Mu:U        $.of;
has Red::AST    $.ast;

method iterator {
    my \of = $!of;
    class :: does Iterator {
        method pull-one {
            [of, IterationEnd xx *][$++]
        }
    }
}
