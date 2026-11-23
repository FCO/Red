use Red::AST;
use Red::AST::Select;
use Red::AST::Insert;
use Red::AST::Update;
use Red::AST::Delete;
use Red::AST::Value;
use Red::AST::LastInsertedRow;
use Red::AST::Function;
use Red::Column;
use Red::RowSecurity;
use Red::RowSecurity::Context;
use Red::Transaction::Guard;

unit module Red::RowSecurity::Write;

my Lock $registry-lock .= new;
my %connection-locks;

sub execute-row-write($driver, Red::AST:D $query) is export {
    my $lock = $registry-lock.protect: {
        %connection-locks{$driver.connection-id} //= Lock.new
    };
    $lock.protect: { perform-row-write($driver, $query) }
}

sub perform-row-write($driver, Red::AST:D $query) {
    policy-context();
    row-security-error('Unsupported protected write operation, including upserts')
        unless $query.WHAT === Red::AST::Insert || $query.WHAT === Red::AST::Update
            || $query.WHAT === Red::AST::Delete;
    row-security-error('This driver cannot guarantee atomic row security writes')
        unless $driver.row-security-capabilities<atomic-write>;
    my $model = $query ~~ Red::AST::Insert ?? $query.into !! $query.model;
    row-security-error('A protected write must identify its model') unless $model.DEFINITE
        || $model ~~ ::('Red::Model');
    $model = $model.WHAT;
    my $operation = $query ~~ Red::AST::Insert ?? 'INSERT'
        !! $query ~~ Red::AST::Update ?? 'UPDATE' !! 'DELETE';
    my $original = policy-model($model);
    if $query ~~ Red::AST::Update {
        for $query.values -> $pair {
            row-security-error('Protected UPDATE assignments require ordinary row columns')
                unless $pair.key ~~ Red::Column && !$pair.key.computation.DEFINITE;
            my @models = row-query-models($pair.value);
            row-security-error('Cross-table UPDATE values are not supported')
                if @models.grep({ !(policy-model($_) === $original) }).elems;
            row-security-error('Subqueries in protected UPDATE values are not supported')
                if $pair.value.transpose-first({ $_ ~~ Red::AST::Select }).DEFINITE;
        }
    }
    my $parent = $driver.?transaction-guard;
    $parent //= Red::Transaction::Guard.new(:driver($driver))
        if $*RED-TRANSACTION-RUNNING;
    my Bool $borrowed = so (($parent.DEFINITE || so $*RED-TRANSACTION-RUNNING)
        && $driver.^can('supports-savepoints') && !$driver.supports-savepoints);
    my $guard = $borrowed ?? $parent
        !! $parent.DEFINITE ?? $parent.child
        !! Red::Transaction::Guard.new(:driver($driver.begin));
    my $connection = $guard.scoped-driver;
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
    # The backend checks trigger/cascade/virtual-table restrictions inside this scope.
    $connection.prepare-row-security([$model]);
    $connection.check-row-security-write($model);
    $connection.lock-row-security-write($query);
    my Red::AST $predicate;
    if $query ~~ Red::AST::Insert {
        $predicate = row-predicate($model, $operation);
        $predicate = map-row-ast($predicate, -> $column {
            my $value = $query.values{$column.name};
            row-security-error('Row policies cannot depend on server-generated insert values')
                unless $value ~~ Red::AST::Value:D && $value.value.DEFINITE;
            $value
        });
    } elsif $query ~~ Red::AST::Update {
        my $new = $original.^alias('red_security_new', :!cache);
        $predicate = row-predicate($model, $operation, :$new);
        my %values = $query.values.map({ .key.name => .value });
        $predicate = map-row-ast($predicate, -> $column {
            if $column.class === $new {
                %values{$column.name} // $model.^columns.first(
                    *.column.name eq $column.name).column
            } else {
                $column
            }
        });
    } else {
        $predicate = row-predicate($model, $operation);
    }
    # WHERE may itself contain subqueries. Until their policies can be secured as
    # independent scopes here, reject them, along with cross-table writes.
    if $query !~~ Red::AST::Insert {
        my @models = row-query-models($query.filter) if $query.filter.DEFINITE;
        row-security-error('Cross-table row security writes are not supported')
            if @models.grep({ !(policy-model($_) === $original)
                || $_.^as ne $model.^as }).elems;
        row-security-error('Row security writes with subqueries are not supported')
            if $query.filter.DEFINITE && $query.filter.transpose-first({
                $_ ~~ Red::AST::Select
            }).DEFINITE;
    }
    $predicate = bind-row-policy($predicate);
    my Int $*bind-counter = 0;
    my $check = $connection.translate($predicate, 'where');
    my Str $sql;
    my @bind = $check.value;
    if $query ~~ Red::AST::Insert {
        $sql = 'SELECT CASE WHEN ' ~ $check.key ~ ' THEN 0 ELSE 1 END AS denied';
    } else {
        my $filter = $connection.translate($query.filter, 'where');
        $sql = 'SELECT 1 AS denied FROM ' ~ $connection.table-name-wrapper($model.^table)
            ~ ' AS ' ~ $connection.table-name-wrapper($model.^as)
            ~ ' WHERE (CASE WHEN ' ~ $check.key ~ ' THEN 0 ELSE 1 END) = 1'
            ~ ($filter.key.chars ?? ' AND (' ~ $filter.key ~ ')' !! '') ~ ' LIMIT 1'
            ~ $connection.row-security-check-suffix;
        @bind.append: $filter.value;
    }
    my $denied := $connection.execute($sql, |@bind).row;
    row-security-error("$operation row security policy rejected the operation")
        if !($denied =:= IterationEnd) && $denied && $denied<denied>;
    # Bypass only the AST prepare entry point after validation on this connection.
    # SQL is generated by the driver, never by a policy or application callback.
    my @statements = (|$connection.translate($query)).map({
        $connection.execute(.key, |.value)
    }).eager;
    # Materialize RETURNING before closing the transaction (SQLite cursors retain locks).
    my @rows;
    if @statements {
        loop {
            my $row := @statements.tail.row;
            last if $row =:= IterationEnd || !$row;
            @rows.push: $row;
        }
    }
    # Recover inserted rows for backends without RETURNING before committing.
    # This is the INSERT result, like RETURNING, rather than a separate SELECT.
    if $query ~~ Red::AST::Insert && !@rows
        && $connection.driver-name eq any(<Red::Driver::SQLite Red::Driver::MySQL>) {
        my Red::AST $filter;
        if $connection.driver-name eq 'Red::Driver::SQLite' {
            $filter = Red::AST::Eq.new: Red::AST::RowId,
                Red::AST::Function.new(:func<last_insert_rowid>);
        } else {
            my @keys = $model.^id.map(*.column);
            @keys = $model.^columns.map(*.column) unless @keys;
            my @filters;
            for @keys -> $column {
                my $value = $query.values{$column.name};
                $value = Red::AST::Function.new(:func<LAST_INSERT_ID>)
                    if $column.auto-increment && (!$value.DEFINITE
                        || ($value ~~ Red::AST::Value && !$value.value.DEFINITE));
                @filters.push: Red::AST::Eq.new($column, $value) if $value.DEFINITE;
            }
            row-security-error('Cannot identify the inserted MySQL row') unless @filters;
            $filter = @filters == 1 ?? @filters.head
                !! @filters.reduce({ Red::AST::AND.new($^a, $^b) });
        }
        my $result = Red::AST::Select.new(:of($model), :table-list[$model], :$filter,
            :1limit, :row-policies{ $model.^as => ast-value(True) });
        for $connection.translate($result) -> $sql {
            my $row := $connection.execute($sql.key, |$sql.value).row;
            @rows.push: $row if !($row =:= IterationEnd) && $row;
        }
    }
    $guard.commit unless $borrowed;
    class Result {
        has @.rows;
        has Map $.context is required;
        method row {
            assert-row-context($!context);
            @!rows ?? @!rows.shift !! {}
        }
    }.new(:rows(@rows), :context(row-security-context()))
}
