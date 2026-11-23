use Red::AST::CreateTable;
use Red::Model;
use Red::RowSecurity;
use Red::RowSecurity::Context;
use Red::Statement;
use Red::Transaction::Guard;

unit module Red::RowSecurity::DDL;

# Explicit metadata covers empty and inherited models. Low-level AST callers can
# also carry the model through their columns; never discard a discovered policy.
sub creation-row-model(Red::AST::CreateTable:D $query) is export {
    return $query.model if $query.model ~~ Red::Model;
    my @protected = $query.columns.map(*.class).grep({ row-protected($_) })
        .unique(:as(*.WHICH.Str));
    return Nil unless @protected;
    my @matching = @protected.grep({ .^table eq $query.name });
    row-security-error('Protected CREATE TABLE requires unambiguous model metadata')
        unless @matching.elems == 1;
    @matching.head
}

class CreationStatement does Red::Statement {
    has Red::AST::CreateTable $.query is required;
    has Str @.policy-sql;

    method stt-exec($, *@bind) {
        row-security-error('Protected table DDL cannot use statement parameters') if @bind;
        my $driver = self.driver;
        my $parent = $driver.?transaction-guard;
        $parent //= Red::Transaction::Guard.new(:$driver)
            if $driver.row-security-transaction-active;
        my $guard = $parent.DEFINITE ?? $parent.child
            !! Red::Transaction::Guard.new(:driver($driver.begin));
        CATCH {
            default {
                my $cause = $_;
                my Exception $cleanup;
                if $guard.DEFINITE {
                    try {
                        $guard.rollback;
                        CATCH { default { $cleanup = $_ } }
                    }
                }
                X::Red::Transaction::Cleanup.new(:$cause, :$cleanup).throw if $cleanup.DEFINITE;
                $cause.rethrow;
            }
        }
        my $connection = $guard.scoped-driver;
        for |$connection.translate($!query) -> $part {
            row-security-error('Protected table DDL cannot contain bound values') if $part.value;
            $connection.execute($part.key) if $part.key.chars;
        }
        $connection.execute($_) for @!policy-sql;
        $guard.commit;
        Nil
    }

    method stt-row($) { {} }
}

sub row-creation-statement($driver, Red::AST::CreateTable:D $query) is export {
    return Nil unless $driver.row-security-capabilities<native>;
    my $model = creation-row-model($query);
    return Nil unless row-protected($model);
    row-security-error('Protected table DDL must target its declared model table')
        unless $query.name eq $model.^table;
    my %policies = row-policy-descriptors($model);
    my @policy-sql = $driver.row-security-schema($model, %policies);
    row-security-error('Native row security DDL is not implemented by this driver')
        unless @policy-sql;
    CreationStatement.new(:$driver, :$query, :@policy-sql)
}
