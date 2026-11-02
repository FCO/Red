=head2 X::Red::Migration

#| Report invalid migration artifacts, unsupported changes or failed execution, optionally
#| retaining an underlying exception as the cause.
unit class X::Red::Migration is Exception;
has Str $.reason is required;
has Exception $.cause;
#| Return the actionable migration reason as the exception message.
method message { $!reason }
