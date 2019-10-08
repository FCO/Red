use Red::AST::Unary;
use Red::AST::Infixes;
use Red::AST::Value;
use Red::AST::StringFuncs;
use Red::AST::DateTimeFuncs;

=head2 Red::ColumnMethods

#| Red::Column methods
unit role Red::ColumnMethods;

#| Tests if that column value starts with a specific sub-string
#| is usually translated for SQL as `column like 'substr%'`
method starts-with(Str() $text) {
    Red::AST::Like.new(self, ast-value "{ $text }%") but Red::ColumnMethods
}

#| Tests if that column value ends with a specific sub-string
#| is usually translated for SQL as `column like '%substr'`
method ends-with(Str() $text) {
    Red::AST::Like.new(self, ast-value "%{ $text }") but Red::ColumnMethods
}

#| Tests if that column value contains a specific sub-string
#| #| is usually translated for SQL as `column like %'substr%'`
method contains(Str() $text) {
    Red::AST::Like.new(self, ast-value "%{ $text }%") but Red::ColumnMethods
}


method substr($base where { .returns ~~ Str }: Int() $offset = 0, Int() $size?) {
    Red::AST::Substring.new(:$base, :$offset, |(:$size with $size)) but Red::ColumnMethods
}


method year($base where { .returns ~~ (Date|DateTime|Instant) }:) {
    Red::AST::DateTimePart.new(:$base, :part(Red::AST::DateTime::Part::year)) but Red::ColumnMethods
}

method month($base where { .returns ~~ (Date|DateTime|Instant) }:) {
    Red::AST::DateTimePart.new(:$base, :part(Red::AST::DateTime::Part::month)) but Red::ColumnMethods
}

method day($base where { .returns ~~ (Date|DateTime|Instant) }:) {
    Red::AST::DateTimePart.new(:$base, :part(Red::AST::DateTime::Part::day)) but Red::ColumnMethods
}