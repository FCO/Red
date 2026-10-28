use Red::SchemaReader;
use Red::Cli::Table;
use Red::Cli::Column;
unit class Red::Driver::Pg::SchemaReader does Red::SchemaReader;
has $.driver is required;
method rows(Str $sql, *@bind) {
    my $statement = $!driver.execute($sql, |@bind);
    gather loop {
            my $row := $statement.row;
            last if $row =:= IterationEnd || !$row;
            take $row;
        }
}
method tables-names {
    self.rows('SELECT tablename AS name FROM pg_tables WHERE schemaname = current_schema() ORDER BY tablename').map(*.<name>)
}
method indexes-of($table) { self.constraints($table) }
method constraints(Str $table) {
    self.rows(q:to/SQL/, $table)
        SELECT c.contype AS kind, c.conname AS name, a.attname AS column_name,
               u.ordinality AS position, rt.relname AS ref_table, ra.attname AS ref_column
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = t.relnamespace
        JOIN LATERAL unnest(c.conkey) WITH ORDINALITY u(attnum, ordinality) ON true
        JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = u.attnum
        LEFT JOIN pg_class rt ON rt.oid = c.confrelid
        LEFT JOIN pg_attribute ra ON ra.attrelid = rt.oid AND ra.attnum = c.confkey[u.ordinality]
        WHERE n.nspname = current_schema() AND t.relname = $1
        ORDER BY c.conname, u.ordinality
        SQL
}
method table-definition(Str $table) {
    my @columns = self.rows(q:to/SQL/, $table);
        SELECT a.attname AS name, format_type(a.atttypid, a.atttypmod) AS type,
               a.attnotnull AS notnull
        FROM pg_attribute a JOIN pg_class t ON t.oid = a.attrelid
        JOIN pg_namespace n ON n.oid = t.relnamespace
        WHERE n.nspname = current_schema() AND t.relname = $1
          AND a.attnum > 0 AND NOT a.attisdropped ORDER BY a.attnum
        SQL
    return Red::Cli::Table.new(:!exists) unless @columns;
    my @keys = self.constraints($table);
    my %unique;
    my %references;
    my %primary;
    for @keys -> $key {
        given $key<kind> {
            when 'p' { %primary{$key<column_name>} = True }
            when 'u' { %unique{$key<name>}.push: $key<column_name> }
            when 'f' {
                %references{$key<column_name>} = %(table => $key<ref_table>, column => $key<ref_column>);
            }
        }
    }
    Red::Cli::Table.new(:name($table), :constraints(%unique.values.Array),
        :columns(@columns.map(-> $column {
            Red::Cli::Column.new(:name($column<name>), :type($column<type>.subst('character varying', 'varchar')),
                :perl-type((try $!driver.type-for-sql($column<type>.subst('character varying', 'varchar'))) // 'Mu'),
                :nullable(!$column<notnull>), :pk(so %primary{$column<name>}),
                :references(%references{$column<name>} // {}))
        }).Array))
}
method table-definition-from-create-table($sql) {
    die 'PostgreSQL schema introspection uses catalog metadata'
}

method column-dependencies(Str $table, Str $column) {
    self.rows(q:to/SQL/, $table, $column).map(*.<name>).Array
        SELECT i.relname AS name FROM pg_index x
        JOIN pg_class t ON t.oid=x.indrelid
        JOIN pg_namespace n ON n.oid=t.relnamespace
        JOIN pg_class i ON i.oid=x.indexrelid
        JOIN pg_attribute a ON a.attrelid=t.oid AND a.attnum=ANY(x.indkey)
        WHERE n.nspname=current_schema() AND t.relname=$1 AND a.attname=$2
        UNION
        SELECT c.conname AS name FROM pg_constraint c
        JOIN pg_class t ON t.oid=c.confrelid
        JOIN pg_namespace n ON n.oid=t.relnamespace
        JOIN pg_attribute a ON a.attrelid=t.oid AND a.attnum=ANY(c.confkey)
        WHERE c.contype='f' AND n.nspname=current_schema() AND t.relname=$1 AND a.attname=$2
        SQL
}
