use Red::AST;
use Red::AST::Unary;
use Red::AST::IsDefined;

#| A typed reference to a column exported by a derived table.
unit class Red::AST::Reference does Red::AST;

has Str $.table is required;
has Str $.name is required;
has Mu:U $.type = Any;
has &.inflate;
has &.deflate;
has Red::AST $.presence;

method returns { $!type }
method args { () }
method tables { () }
method find-column-name { $!name }
method gist { "$!table.$!name" }
method cast(Str $type) { Red::AST::Cast.new(self, $type) }
method defined { Red::AST::IsDefined.new(self) }
method not { Red::AST::Not.new(self) }

submethod TWEAK() {
    if $!type.HOW ~~ Metamodel::ClassHOW && $!type.^can("red-type-db-methods") {
        self does $!type.red-type-db-methods;
    }
}
