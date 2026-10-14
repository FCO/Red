use JSON::Fast;
use Red::Type;
use Red::DB;
use X::Red::Exceptions;
unit class Json is Str does Red::Type;

method inflator {
    -> $data {
        CATCH {
            default { X::Red::Json.new(:operation<inflate>, :cause($_)).throw }
        }
        get-RED-DB.?stringify-json && $data ~~ Str ?? from-json($data) !! $data
    }
}

method deflator {
    -> $data {
        CATCH {
            default { X::Red::Json.new(:operation<deflate>, :cause($_)).throw }
        }
        # The Json type object denotes SQL NULL; Any/Nil denote JSON null.
        $data === Json ?? Json
            !! get-RED-DB.?stringify-json ?? to-json($data, :!pretty) !! $data
    }
}

method red-type-accepts(Any:U --> Bool) { True }

method red-type-default { Json }
