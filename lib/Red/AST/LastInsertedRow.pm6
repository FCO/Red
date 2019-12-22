use Red::AST;
use Red::Model;

#| Represents the last inserted row
class Red::AST::LastInsertedRow does Red::AST {

    has Mu:U $.of;

    method returns { Red::Model }
    method args { $!of }

    method new($of) { ::?CLASS.bless: :$of }
    method find-column-name {}
}

class Red::AST::RowId does Red::AST {
    method returns { Int }
    method args {}
    method find-column-name {}
}
