unit class X::Red::Migration is Exception;
has Str $.reason is required;
method message { $!reason }
