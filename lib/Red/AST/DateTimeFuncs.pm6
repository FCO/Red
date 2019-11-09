use Red::AST;
use Red::AST::Value;
use Red::AST::Function;

role Red::AST::DateTimeFunction does Red::AST {
    method default-implementation {...}

}
enum Red::AST::DateTime::Part (
        year   => "%Y",
        month  => "%m",
        day    => "%d",
        hour   => "%H",
        minute => "%M",
        second => "%S",
);

class Red::AST::DateTimePart does Red::AST::DateTimeFunction {
    has Red::AST                 $.base;
    has Red::AST::DateTime::Part $.part;

    method returns { Str }
    method find-column-name {
        $!base.find-column-name
    }
    method args {$!base, $!part}

    method default-implementation {

        Red::AST::Function.new:
                :func<STRFTIME>,
                :args[
                    ast-value($!part.value),
                    Red::AST::Function.new:
                        :func<DATE>,
                        :args[ $!base ],
                ]
    }
}
