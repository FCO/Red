use Red::AST::Unary;
use Red::AST::Infixes;
use Red::AST::Value;

unit role Red::ColumnMethods;


method starts-with(Str() $text) { Red::AST::Like.new: self, ast-value "{ $text }%" }
method ends-with(Str() $text) { Red::AST::Like.new: self, ast-value "%{ $text }" }
method contains(Str() $text) { Red::AST::Like.new: self, ast-value "%{ $text }%" }

