use Red::Statement;
use Red::AST;
use Red::Transaction::Guard;
use Red::RowSecurity::Context;

# A native RLS read outside red-do :transaction owns a short transaction on the
# execution connection. Drain the cursor before returning it to the connection pool.
unit class Red::RowSecurity::Statement does Red::Statement;
has Red::AST $.query is required;
has Iterator $!rows;
method stt-exec($, *@bind) {
    my $guard = Red::Transaction::Guard.new(:driver(self.driver.begin));
    CATCH {
        default {
            my $cause = $_;
            try $guard.rollback;
            $cause.rethrow;
        }
    }
    my @statements = $guard.scoped-driver.prepare($!query);
    .execute(|@bind) for @statements;
    my @rows;
    if @statements {
        loop {
            my $row := @statements.tail.row;
            last if $row =:= IterationEnd || !$row;
            @rows.push: $row;
        }
    }
    $guard.commit;
    $!rows = @rows.iterator;
    Nil
}
method stt-row($) {
    my $row := $!rows.pull-one;
    $row =:= IterationEnd ?? {} !! $row
}
