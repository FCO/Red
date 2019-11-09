use Red::AST::Unary;
use Red::AST::Infixes;
use Red::AST::Value;
use Red::AST::StringFuncs;
use Red::AST::DateTimeFuncs;
use Red::AST::JsonItem;
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
#| #| is usually translated for SQL as `column like %'substr%'`
multi method contains(Str() $text is readonly) {
    Red::AST::Like.new(self, ast-value "%{ $text }%") but Red::ColumnMethods
}

multi method contains(Str() $text is rw) {
    Red::AST::Like.new(self, ast-value("%{ $text }%"), :bind-left) but Red::ColumnMethods
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


method AT-KEY(\SELF where { .returns ~~ Json }: $key where { $_ ~~ Str or ( $_ ~~ Red::AST and .returns ~~ Str )}) is rw {
    my $obj = Red::AST::JsonItem.new(SELF, ast-value $key);
    Proxy.new:
            FETCH => -> $ { $obj but Red::ColumnMethods },
            STORE => -> $, $value {
                @*UPDATE.push: Pair.new: $obj, ast-value $value;
                $obj but Red::ColumnMethods
            }
}

method AT-POS(\SELF where { .returns ~~ Json }: $key where { $_ ~~ Int or ( $_ ~~ Red::AST and .returns ~~ Int )}) is rw {
    my $obj = Red::AST::JsonItem.new(SELF, ast-value $key);
    Proxy.new:
            FETCH => -> $ { $obj but Red::ColumnMethods },
            STORE => -> $, $value {
                @*UPDATE.push: Pair.new: $obj, ast-value $value;
                $obj but Red::ColumnMethods
            }
}