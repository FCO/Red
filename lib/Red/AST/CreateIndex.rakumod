use Red::AST;

#| A local column reference in index DDL, without query qualification or aliases.
class Red::AST::IndexColumn does Red::AST {
    has Str $.name is required;
    has Mu:U $.value-type = Any;
    method returns { $!value-type }
    method args { () }
    method find-column-name { $!name }
}

#| An ordered index definition. Inline unique constraints share this metadata.
class Red::AST::CreateIndex does Red::AST {
    has Str $.table is required;
    has Str $.name is required;
    has Str $.logical-name is required;
    has Bool $.unique = False;
    has Bool $.inline = False;
    has Red::AST @.keys;
    has Str $.using = '';
    has Str $.driver = '';
    has Str @.opclasses;
    has Red::AST $.predicate;

    method returns { Nil }
    method args { |@!keys }
    method find-column-name { @!keys.map(*.find-column-name).flat }
}
