use Red::AST;
use Red::AST::Value;
use Red::AST::Function;

role Red::AST::StringFunction does Red::AST {
    method default-implementation {...}

}
class Red::AST::Substring does Red::AST::StringFunction {
    has Red::AST $.base;
    has Int      $.offset = 0;
    has Int      $.size;

    method returns { Str }
    method find-column-name {
        $!base.find-column-name
    }
    method args {$!base, $!offset, $!size}

    method default-implementation {
        Red::AST::Function.new: :func<SUBSTR>, :args[$!base, ast-value($!offset + 1), |(.&ast-value with $!size)]
    }
}
