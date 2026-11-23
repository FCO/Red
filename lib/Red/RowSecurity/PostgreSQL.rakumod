use Red::RowSecurity::Context;
use JSON::Fast;

unit module Red::RowSecurity::PostgreSQL;

sub policy-version(%policies --> Str:D) is export {
    my Str $canonical = %policies.keys.sort.map({ $_ ~ '=' ~ %policies{$_}.raku }).join('|');
    my Int $hash = 14695981039346656037;
    for $canonical.encode.list -> $byte {
        $hash = (($hash +^ $byte) * 1099511628211) +& 0xffffffffffffffff;
    }
    $hash.base(16).lc
}

sub native-policy-name(Str:D $operation, %policies --> Str:D) is export {
    'red_rls_' ~ $operation.lc ~ '_' ~ policy-version(%policies)
}

sub native-policy-fingerprint(--> Str:D) is export {
    q[md5(polcmd::text || ':' || polpermissive::text || ':' || array_to_string(polroles, ',')
        || ':' || coalesce(pg_get_expr(polqual, polrelid), '') || ':'
        || coalesce(pg_get_expr(polwithcheck, polrelid), ''))]
}

sub native-policy-sql($driver, Str:D $table, %policies --> Array:D) is export {
    return [] unless %policies;
    my $quoted = $driver.table-name-wrapper($table);
    sub quote(Str:D $text) { "'" ~ $text.subst("'", "''", :g) ~ "'" }
    sub uses(@part, Str:D $state --> Bool:D) {
        return @part[1] eq $state if @part[0] eq 'column';
        return False if @part[0] eq any(<context value>);
        so @part.skip(1).grep({ $_ ~~ Positional && uses($_, $state) })
    }
    sub render(@part, Str:D $scope, Str:D $expected = 'boolean') {
        my $kind = @part[0];
        # Mixed old/new comparisons are checked atomically by Red. Only predicates
        # representable in this PostgreSQL row scope enter the native policy.
        if $scope eq any(<using check>) {
            my $other = $scope eq 'using' ?? 'new' !! 'old';
            if $kind eq 'and' {
                return '(' ~ @part.skip(1).map({ render($_, $scope) }).join(' AND ') ~ ')';
            }
            return 'TRUE' if uses(@part, $other);
        }
        return $driver.table-name-wrapper(@part[2]) if $kind eq 'column';
        if $kind eq 'context' {
            return "((NULLIF(current_setting('red.row_context', true), '')::jsonb ->> "
                ~ quote(@part[1]) ~ ')::' ~ $expected ~ ')';
        }
        if $kind eq 'value' {
            return 'NULL' unless @part[1].DEFINITE;
            return @part[1] ?? 'TRUE' !! 'FALSE' if @part[1].WHAT === Bool;
            return @part[1].Str if @part[1] ~~ Numeric;
            return quote(@part[1]);
        }
        if $kind eq 'cast' {
            my $type = @part[1] eq 'num' ?? 'numeric'
                !! @part[1] eq 'int' ?? 'bigint' !! 'text';
            return '(' ~ render(@part[2], $scope, $type) ~ ')::' ~ $type;
        }
        return '(NOT ' ~ render(@part[1], $scope) ~ ')' if $kind eq 'not';
        return render(@part[1], $scope) if $kind eq 'so';
        my %operators = eq => '=', ne => '<>', lt => '<', le => '<=', gt => '>',
            ge => '>=', and => 'AND', or => 'OR';
        row-security-error('Unsupported native row policy expression')
            unless %operators{$kind}:exists;
        # Numeric Red comparisons wrap the column in a numeric cast. Give a
        # context slot on the other side the same SQL type.
        my $expected-type = @part.skip(1).grep({ $_[0] eq 'cast' && $_[1] eq 'num' })
            ?? 'numeric' !! 'text';
        '(' ~ render(@part[1], $scope, $expected-type) ~ ' ' ~ %operators{$kind}
            ~ ' ' ~ render(@part[2], $scope, $expected-type) ~ ')'
    }
    my @sql = "ALTER TABLE $quoted ENABLE ROW LEVEL SECURITY",
        "ALTER TABLE $quoted FORCE ROW LEVEL SECURITY";
    for <select insert update delete> -> $operation {
        my $name = $driver.table-name-wrapper(native-policy-name($operation, %policies));
        my $predicate = %policies{$operation};
        my $using = render($predicate, $operation eq 'update' ?? 'using' !! 'row');
        my $check = render($predicate, $operation eq 'update' ?? 'check' !! 'row');
        my $sql = "CREATE POLICY $name ON $quoted FOR {$operation.uc} TO PUBLIC";
        $sql ~= " USING ($using)" unless $operation eq 'insert';
        $sql ~= " WITH CHECK ($check)" if $operation eq any(<insert update>);
        @sql.push: $sql;
        my $version = policy-version(%policies);
        my $literal-name = quote(native-policy-name($operation, %policies));
        @sql.push: 'DO $red_security$ DECLARE signature text; BEGIN SELECT '
            ~ native-policy-fingerprint() ~ ' INTO signature FROM pg_policy WHERE polrelid = '
            ~ 'to_regclass(' ~ quote($quoted) ~ ') AND polname = ' ~ $literal-name ~ '; '
            ~ 'EXECUTE ' ~ quote('COMMENT ON POLICY ' ~ $name ~ ' ON ' ~ $quoted ~ ' IS ')
            ~ ' || quote_literal(' ~ quote($version ~ ':') ~ ' || signature); '
            ~ 'END $red_security$';
    }
    @sql.Array
}

# Only explicit migrations/synchronization replace policies on existing tables.
sub native-policy-change($driver, $old, $new --> Array:D) is export {
    my $table = $driver.table-name-wrapper($new.name);
    sub quote(Str:D $text) { "'" ~ $text.subst("'", "''", :g) ~ "'" }
    # Live schema synchronization has no historical model descriptors. Reconcile
    # this library's namespace without deleting independently managed policies.
    my @sql = 'DO $red_security$ DECLARE policy_name text; BEGIN FOR policy_name IN '
        ~ 'SELECT polname FROM pg_policy WHERE polrelid = to_regclass(' ~ quote($table) ~ ')'
        ~ q[ AND left(polname, 8) = 'red_rls_' LOOP EXECUTE 'DROP POLICY ' ]
        ~ '|| quote_ident(policy_name) || ' ~ quote(' ON ' ~ $table)
        ~ '; END LOOP; END $red_security$';
    if $new.row-policies {
        @sql.append: $new.row-security-sql;
    } else {
        @sql.push: "ALTER TABLE $table NO FORCE ROW LEVEL SECURITY",
            "ALTER TABLE $table DISABLE ROW LEVEL SECURITY";
    }
    @sql.Array
}
