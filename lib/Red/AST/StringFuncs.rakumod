use Red::AST;
use Red::AST::Value;
use Red::Operators;
use Red::AST::Function;

#| Base role for string functions
role Red::AST::StringFunction does Red::AST {
    method default-implementation {...}

}

#| Represents a substring call
class Red::AST::Substring does Red::AST::StringFunction {
    has Red::AST $.base;
    has $.offset = ast-value 0;
    has $.size;

    method returns { Str }
    method find-column-name {
        $!base.find-column-name
    }
    method args {$!base, $!offset, $!size}

    method default-implementation {
        Red::AST::Function.new: :func<SUBSTR>, :args[$!base, ($!offset ~~ Red::AST ?? ast-value($!offset) !! ast-value($!offset) + 1), |(.&ast-value - 1 with $!size)]
    }
}

#| Represents a index call
class Red::AST::Index does Red::AST::StringFunction {
    has Red::AST $.base;
    has          $.needle;

    method returns { Int }
    method find-column-name {
        $!base.find-column-name
    }
    method args {$!base, $!needle}

    method default-implementation {
        Red::AST::Function.new: :func<INSTR>, :args[$!base, ast-value($!needle)]
    }
}
