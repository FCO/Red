use Red::AST::Unary;
use Red::AST::Infixes;
use Red::AST::Value;

#| Red::Column methods
unit role Red::ColumnMethods;

#| Tests if that column value starts with a specific sub-string
#| is usually translated for SQL as `column like 'substr%'`
method starts-with(Str() $text) { Red::AST::Like.new: self, ast-value "{ $text }%" }

#| Tests if that column value ends with a specific sub-string
#| is usually translated for SQL as `column like '%substr'`
method ends-with(Str() $text) { Red::AST::Like.new: self, ast-value "%{ $text }" }

#| Tests if that column value contains a specific sub-string
#| #| is usually translated for SQL as `column like %'substr%'`
method contains(Str() $text) { Red::AST::Like.new: self, ast-value "%{ $text }%" }

