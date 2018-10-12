unit class X::Red::InvalidTableName is Exception;

has Str $.table;
has Str $.driver;

method message { "'$!table' is an invalid table name for driver $!driver" }
