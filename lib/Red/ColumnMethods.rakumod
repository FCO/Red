use Red::AST::Unary;
use Red::AST::Infixes;
use Red::AST::Value;
use Red::AST::StringFuncs;
use Red::AST::DateTimeFuncs;
use Red::AST::JsonItem;
use Red::AST::JsonRemoveItem;
use Red::Type::Json;

=head2 Red::ColumnMethods

#| Red::Column methods
unit role Red::ColumnMethods;

#| Tests if that column value starts with a specific sub-string
#| is usually translated for SQL as `column like 'substr%'`
multi method starts-with(Str() $text is readonly) {
    Red::AST::Like.new(self, ast-value "{ $text }%") but Red::ColumnMethods
}

multi method starts-with(Str() $text is rw) {
    Red::AST::Like.new(self, ast-value("{ $text }%"), :bind-left) but Red::ColumnMethods
}

#| Tests if that column value ends with a specific sub-string
#| is usually translated for SQL as `column like '%substr'`
multi method ends-with(Str() $text is readonly) {
    Red::AST::Like.new(self, ast-value "%{ $text }") but Red::ColumnMethods
}

multi method ends-with(Str() $text is rw) {
    Red::AST::Like.new(self, ast-value("%{ $text }"), :bind-left) but Red::ColumnMethods
}

#| Tests if that column value contains a specific sub-string
#| is usually translated for SQL as `column like %'substr%'`
multi method contains(Str() $text is readonly) {
    Red::AST::Like.new(self, ast-value "%{ $text }%") but Red::ColumnMethods
}

multi method contains(Str() $text is rw) {
    Red::AST::Like.new(self, ast-value("%{ $text }%"), :bind-left) but Red::ColumnMethods
}

#| Return a lowercased string
multi method lc($string:) {
    Red::AST::Lowercase.new(:$string) but Red::ColumnMethods
}

#| Return a lowercased string
multi method fc($string:) {
    Red::AST::Lowercase.new(:$string) but Red::ColumnMethods
}

#| Return a uppercased string
multi method uc($string:) {
    Red::AST::Uppercase.new(:$string) but Red::ColumnMethods
}

#| Return a substring of the column value
multi method substr($base where { .returns ~~ Str }: $offset = ast-value(0), $size?) {
    Red::AST::Substring.new(:$base, :$offset, |(:$size with $size)) but Red::ColumnMethods
}

#| Return a substring of the column value
multi method substr($base: $offset = ast-value(0), $size?) {
    Red::AST::Substring.new(:base(Red::AST::Cast.new: $base, "str"), :$offset, |(:$size with $size)) but Red::ColumnMethods
}

#| Return a index of the column value
multi method index($base where { .returns ~~ Str }: $needle) {
    Red::AST::Index.new(:$base, :$needle) but Red::ColumnMethods
}

#| Return a index of the column value
multi method index($base: $needle) {
    Red::AST::Index.new(:base(Red::AST::Cast.new: $base, "str"), :$needle) but Red::ColumnMethods
}

#| Return the year from the date column
method year($base where { .returns ~~ (Date|DateTime|Instant) }:) {
    Red::AST::Mul.new(ast-value(1), Red::AST::DateTimePart.new(:$base, :part(Red::AST::DateTime::Part::year))) but Red::ColumnMethods
}

#| Return the month from the date column
method month($base where { .returns ~~ (Date|DateTime|Instant) }:) {
    Red::AST::Mul.new(ast-value(1), Red::AST::DateTimePart.new(:$base, :part(Red::AST::DateTime::Part::month))) but Red::ColumnMethods
}

#| Return the day from the date column
method day($base where { .returns ~~ (Date|DateTime|Instant) }:) {
    Red::AST::Mul.new(ast-value(1), Red::AST::DateTimePart.new(:$base, :part(Red::AST::DateTime::Part::day))) but Red::ColumnMethods
}

#| Return the date from a datetime, timestamp etc
method yyyy-mm-dd($base where { .returns ~~ (Date|DateTime|Instant) }:) {
     Red::AST::DateTimeCoerce.new(:$base) but Red::ColumnMethods
}

method now   { Red::AST::DateTimeNow.new }
method today { Red::AST::DateTimeToday.new }

#| Return a value from a json hash key
multi method AT-KEY(\SELF where { .returns ~~ Json }: $key where { $_ ~~ Str or ( $_ ~~ Red::AST and .returns ~~ Str )}) is rw {
    my $obj = Red::AST::JsonItem.new(SELF, ast-value $key);
    Proxy.new:
            FETCH => -> $ { $obj but Red::ColumnMethods },
            STORE => -> $, $value {
                my $val = do given $value {
                    when Red::AST { $_ }
                    default {
                        my &deflator = Json.deflator;
                        ast-value :type(Json), .&deflator;
                    }
                }
                @*UPDATE.push: Pair.new: $obj, $val;
                $obj but Red::ColumnMethods
            }
}

#| Delete and return a value from a json hash key
multi method DELETE-KEY(\SELF where { .returns ~~ Json }: $key where { $_ ~~ Str or ( $_ ~~ Red::AST and .returns ~~ Str )}) {
    my $obj = Red::AST::JsonItem.new(SELF, ast-value $key);
    @*UPDATE.push: Pair.new: SELF, Red::AST::JsonRemoveItem.new: SELF, ast-value $key;
    $obj
}

#| Returns a value from a json array index
method AT-POS(\SELF where { .returns ~~ Json }: $key where { $_ ~~ Int or ( $_ ~~ Red::AST and .returns ~~ Int )}) is rw {
    my $obj = Red::AST::JsonItem.new(SELF, ast-value $key);
    Proxy.new:
            FETCH => -> $ { $obj but Red::ColumnMethods },
            STORE => -> $, $value {
                my $val = do given $value {
                    when Red::AST { $_ }
                    default {
                        my &deflator = Json.deflator;
                        ast-value .&deflator, :type(Json)
                    }
                }
                @*UPDATE.push: Pair.new: $obj, $val;
                $obj but Red::ColumnMethods
            }
}
