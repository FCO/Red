unit module Red::Type::Map;

multi to-raku-type("numeric") is export { Numeric }
multi to-raku-type("text")    is export { Str }
