use Red::AST;

#| Character count of a scalar capture, using native database character units.
unit class Red::AST::RegexChars does Red::AST;

has Red::AST $.value is required;
method returns { Int }
method args { $!value, }
method find-column-name { $!value.find-column-name }
