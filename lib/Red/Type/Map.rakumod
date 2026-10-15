unit module Red::Type::Map;

multi to-raku-type("numeric") is export { Numeric }
multi to-raku-type("text")    is export { Str }
multi to-raku-type("str")     is export { Str }
multi to-raku-type("int")     is export { Int }
multi to-raku-type("integer") is export { Int }
multi to-raku-type("num")     is export { Numeric }
multi to-raku-type("bool")    is export { Bool }
multi to-raku-type("boolean") is export { Bool }
multi to-raku-type("datetime") is export { DateTime }
multi to-raku-type("date")     is export { Date }
