use Red::AST;
unit class Red::DoneResultSeq is Seq;

class ResultSeq::Iterator does Iterator {
    has Mu:U        $.of;
    has Red::AST    $.filter;

    method pull-one {
        $!of.new
    }
}

has Mu:U        $.of;
has Red::AST    $.filter;

method new(:$of, :$filter) {
    ::?CLASS.bless: :$of, :$filter
}

method iterator {
    ResultSeq::Iterator.new: :$!of, :$!filter
}
