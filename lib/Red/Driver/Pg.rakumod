use DB::Pg;
use Red::Driver;
use Red::Driver::CommonSQL;
use Red::Statement;
use Red::AST::Unary;
use Red::AST::Infixes;
use Red::AST::Value;
use X::Red::Exceptions;
use Red::AST::TableComment;
use Red::Type::Json;
use Red::AST::JsonOperation;
use Red::Projection;
use Red::AST::JsonSetItem;
use Red::LockType;
use Red::Index;
need UUID;

unit class Red::Driver::Pg does Red::Driver::CommonSQL;

has Str $!user;
has Str $!password;
has Str $!host;
has Int $!port;
has Str $!dbname;
has $.dbh;

method schema-reader {}

method indexes-for-table(Str $table --> Array) {
    my @indexes;
    my $statement = self.execute(q:to/SQL/, self.table-name-wrapper($table));
        SELECT c.relname AS name, i.indisunique AS is_unique,
               i.indpred IS NOT NULL AS partial, i.indexrelid AS oid,
               i.indnkeyatts AS key_count, i.indisvalid AND i.indisready AS valid
        FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid
        WHERE i.indrelid = to_regclass($1)
        SQL
    for self.index-catalog-rows($statement) -> $row {
        my @keys;
        my $keys = self.execute(q:to/SQL/, $row<oid>, $row<key_count>);
            SELECT pg_get_indexdef($1::oid, n, true) AS key
            FROM generate_series(1, $2::integer) AS n ORDER BY n
            SQL
        for self.index-catalog-rows($keys) -> $key {
            @keys.push: $key<key>;
        }
        @indexes.push: { :name($row<name>), :unique(so $row<is_unique>),
            :partial(so $row<partial>), :valid(so $row<valid>), :keys(@keys.Array) };
    }
    @indexes.Array
}

# Data accepted by the Pg driver constructor:
# dbh     : DB::Pg object
# user    : User to be used to connect to the database
# password: Password to be used to connect to the database
# host    : To be connected to
# port    : What port to connect
# dbname  : Database name
submethod BUILD(:$!dbh, Str :$!user, Str :$!password, Str :$!host = "127.0.0.1", Int :$!port = 5432, Str :$!dbname) {}

submethod TWEAK() {
    $!dbh //= DB::Pg.new:
        conninfo => "{
            "user=$_" with $!user
        } {
            "password=$_" with $!password
        } {
            "host=$_" with $!host
        } {
            "port=$_" with $!port
        } {
            "dbname=$_" with $!dbname
        }"
    ;
}

# JSON values are stringified when binding/reading
method stringify-json { True }

method new-connection($dbh = $!dbh) { self.clone: dbh => $dbh }

method begin {
    my $dbh = $!dbh.db;
    $dbh.begin;
    self.new-connection: $dbh
}

method commit { $!dbh.commit.finish }
method rollback { $!dbh.rollback }

multi method translate(Red::AST::DateTimePart $part, $context?) {
    my ($sql, @bind) := do given self.translate($part.base, $context) { .key, .value }
    "EXTRACT({ $part.part.key.uc } FROM { $sql })" => @bind
}

multi method agg-prefetch($_) {
    qq:to/END/;
    json_agg(json_build_object({
    .^columns.map({
        "'{ .column.attr-name }', { self.table-name-wrapper: .package.^table }.{ .column.name }"
    }).join: ", "
    })) as json
    END
}

# Postgres uses $1, $2 ... style placeholders
method wildcard { '$' ~ ++$*bind-counter }

multi method translate(Red::AST::Not $_ where .value ~~ Red::Column, $context?) {
    self.translate: Red::AST::Cast.new(.value, "boolean").not
}

multi method translate(Red::AST::AND $_ where .left ~~ Red::Column, $context?) {
    self.translate: Red::AST::AND.new: Red::AST::Cast.new(.left, "boolean"), .right
}

multi method translate(Red::AST::AND $_ where .right ~~ Red::Column, $context?) {
    self.translate: Red::AST::AND.new: .left, Red::AST::Cast.new(.right, "boolean")
}

multi method translate(Red::AST::OR $_ where .left ~~ Red::Column, $context?) {
    self.translate: Red::AST::OR.new: Red::AST::Cast.new(.left, "boolean"), .right
}

multi method translate(Red::AST::OR $_ where .right ~~ Red::Column, $context?) {
    self.translate: Red::AST::OR.new: .left, Red::AST::Cast.new(.right, "boolean")
}

multi method translate(Red::AST::Cast $_ where { .type eq "boolean" && .value.?returns ~~ DateTime }, $context?) {
    self.translate: Red::AST::IsDefined.new: .value;
}

multi method translate(Red::AST::Cast $_, $context?) {
    my &trans = sub ($_) {
        when "str"      { "TEXT"      }
        when "int"      { "INTEGER"   }
        when "num"      { "NUMERIC"   }
        when "datetime" { "TIMESTAMP" }
        when "date"     { "DATE"      }
        when "json"     { "JSONB"     }
        when "uuid"     { "UUID"      }
        when "blob"     { "BYTEA"     }
        default { $_ }
    }
    when Red::AST::Value {
        .bind ?? self.translate(.value, "bind") !! qq|'{ .value }'| => []
    }
    default {
        my ($str, @bind) := do given self.translate: .value, .bind ?? "bind" !! $context { .key, .value }
        "({ $str })::{ .type.&trans }" => @bind
    }
}

# Translate string functions that differ on Pg
multi method translate(Red::AST::Index $_, $context?) {
    my ($base, @bb) := do given self.translate: .base, $context { .key, .value };
    my $needle = do given .needle {
        when Red::AST { $_ }
        default { ast-value $_ }
    };
    my ($needles, @nb) := do given self.translate: $needle, $context { .key, .value };
    "STRPOS($base, $needles)" => [|@bb, |@nb]
}

# MINUS is EXCEPT in Postgres
multi method translate(Red::AST::Minus $ast, "multi-select-op") { "EXCEPT" => [] }

#| Builds a bound text array so JSON keys never become SQL syntax.
method pg-jsonb-path(Red::AST $path) {
    my @bind;
    my @sql = self.json-path-items($path).map: -> $item {
        my ($sql, @values) := do given self.translate($item, "bind") { .key, .value };
        @bind.append: @values;
        "($sql)::text"
    };
    "ARRAY[{ @sql.join(', ') }]::text[]" => @bind
}

multi method translate(Red::AST::JsonItem $_, $context?) {
    my ($left, @lb) := do given self.translate: .left, $context { .key, .value };
    my ($path, @pb) := do given self.pg-jsonb-path(.right) { .key, .value };
    "($left #> $path)" => [|@lb, |@pb]
}

multi method translate(Red::AST::JsonRemoveItem $_, $context?) {
    my ($left, @lb) := do given self.translate: .left, $context { .key, .value };
    my ($path, @pb) := do given self.pg-jsonb-path(.right) { .key, .value };
    "($left #- $path)" => [|@lb, |@pb]
}

multi method translate(Red::AST::Value $_ where {
    .type ~~ Pair and .value.key ~~ Red::AST::JsonItem
}, "update") {
    my $item = .value.key;
    self.translate: ast-value($item.left => Red::AST::JsonSetItem.new(
        :left($item.left), :right($item.right), :value(.value.value))), "update"
}

multi method translate(Red::AST::JsonSetItem $_, $context?) {
    my ($left, @lb) := do given self.translate(.left, $context) { .key, .value };
    my ($path, @pb) := do given self.pg-jsonb-path(.right) { .key, .value };
    my ($value, @vb) := do given self.translate(.value, "json-value") { .key, .value };
    my $json = .value.returns ~~ Json
        ?? "COALESCE(($value)::jsonb, 'null'::jsonb)"
        !! "COALESCE(to_jsonb($value), 'null'::jsonb)";
    "jsonb_set($left, $path, $json, true)" => [|@lb, |@pb, |@vb]
}

multi method translate(Red::AST::Value $_ where { .type ~~ Json }, "json-value") {
    "({ self.wildcard })::text::jsonb" => [self.wildcard-value($_)]
}

multi method translate(Red::AST::Value $_ where { .type ~~ Json }, "update-rval") {
    return "NULL" => [] if .value === Json;
    "({ self.wildcard })::text::jsonb" => [self.wildcard-value($_)]
}

multi method translate(Red::AST::Value $_ where { .type ~~ Json }, $context?
    where { !.defined || $_ ne "bind" }) {
    "({ self.wildcard })::text::jsonb" => [self.wildcard-value($_)]
}

#| Ask DB::Pg for serialized JSON so strings and JSON null survive inflation.
multi method translate(Red::Column $col where { .attr.type ~~ Json }, "select",
    Str :$RED-OVERRIDE-COLUMN-AS-PREFIX) {
    my ($value, @bind) := do if $col.computation.DEFINITE {
        self.translate($col.computation, "json-value").kv
    } else {
        "{ self.table-name-wrapper($col.model.^as) }.{ $col.name }", []
    };
    my $alias = ($RED-OVERRIDE-COLUMN-AS-PREFIX.defined
        ?? "$RED-OVERRIDE-COLUMN-AS-PREFIX." !! '') ~ $col.attr-name;
    "($value)::text AS { self.table-name-wrapper($alias) }" => @bind
}

multi method translate(Red::AST::Value $_ where { .type !~~ Json }, "json-value") {
    my $type = .type ~~ Bool ?? "boolean"
        !! .type ~~ Numeric ?? "numeric" !! "text";
    my $value = .type ~~ Bool ?? (.value ?? 'true' !! 'false') !! self.wildcard-value($_);
    "({ self.wildcard })::$type" => [$value]
}

#| JSON arithmetic uses SQL numbers; comparisons with scalars use the scalar's type.
multi method translate(Red::AST::Infix $_ where {
    .op eq any('+', '-', '*', '/', '%', '=', '!=', '<', '>', '<=', '>=')
        && (.left.returns ~~ Json || .right.returns ~~ Json)
}, $context?) {
    self.pg-json-infix($_, $context)
}

multi method translate(Red::AST::Mod $_ where {
    .left.returns ~~ Json || .right.returns ~~ Json
}, $context?) {
    self.pg-json-infix($_, $context)
}

method pg-json-infix(Red::AST::Infix $_, $context?) {
    my $arithmetic = .op eq any(<+ - * / %>);
    my $both-json = .left.returns ~~ Json && .right.returns ~~ Json;
    my @bind;
    my @sql;
    for (.left, .right), (.right, .left) -> ($operand, $other) {
        my $bind = $operand =:= .left ?? .bind-left !! .bind-right;
        my ($raw-sql, @values) := do given self.translate(
            $operand, $bind ?? "bind" !! $context
        ) {
            .key, .value
        };
        my $sql = $raw-sql;
        @bind.append: @values;
        if $operand.returns ~~ Json && ($arithmetic || !$both-json) {
            my $type = $arithmetic || $other.returns ~~ Numeric ?? "numeric"
                !! $other.returns ~~ Bool ?? "boolean" !! "text";
            $sql = "(($sql) #>> ARRAY[]::text[])::$type";
        }
        @sql.push: $sql;
    }
    "({ @sql[0] } { .op } { @sql[1] })" => @bind
}

multi method translate(Red::AST::JsonOperation $operation, $context?) {
    my ($value, @bind) := do given self.translate($operation.value, "json-value") {
        .key, .value
    };
    given $operation.operation {
        when "exists" { "($value IS NOT NULL)" => @bind }
        when "elems" {
            my $presence = $operation.presence.DEFINITE ?? $operation.presence
                !! Red::Projection.json-presence($operation.value);
            my ($present, @pb) := self.translate($presence, $context).kv;
            "(SELECT CASE WHEN NOT j.present THEN 0 ELSE CASE jsonb_typeof(j.value) "
                ~ "WHEN 'array' THEN jsonb_array_length(j.value) "
                ~ "WHEN 'object' THEN (SELECT count(*) FROM jsonb_object_keys(j.value)) "
                ~ "ELSE 1 END END FROM (SELECT $value AS value, $present AS present) j)"
                => [|@bind, |@pb]
        }
        when "contains" {
            my ($argument, @ab) := do given self.translate($operation.argument, "json-value") {
                .key, .value
            };
            "($value @> ($argument)::jsonb)" => [|@bind, |@ab]
        }
    }
}

multi method translate(Red::Column $_, "column-auto-increment") {}

multi method translate(Red::AST::Select $_, $context?, :$gambi where !*.defined) {
    if $*bind-counter.defined {
        return self.Red::Driver::CommonSQL::translate($_, $context, :gambi);
    }
    {
        my Int $*bind-counter = 0;
        self.Red::Driver::CommonSQL::translate($_, $context, :gambi);
    }
}

multi method translate(Red::AST::Reference $_ where { .returns ~~ Json }, $context?) {
    "({ self.table-name-wrapper(.table) }.{ self.table-name-wrapper(.name) })::jsonb" => []
}

multi method translate(Red::AST::Update $_, $context?, :$gambi where !*.defined) {
    my Int $*bind-counter;
    my $*red-subselect-for = UPDATE;
    self.Red::Driver::CommonSQL::translate($_, $context, :gambi);
}

multi method wildcard-value(@val) { @val.map: { self.wildcard-value: $_ } }
multi method wildcard-value($_ where { .HOW ~~ Metamodel::EnumHOW }) { .value }
multi method wildcard-value(Red::AST::Value $_) { self.wildcard-value: .get-value }
multi method wildcard-value(Bool $_) { .Int }
multi method wildcard-value($_) { $_ }

multi method translate(Red::AST::RowId $_, $context?) { "OID" => [] }

multi method translate($, "delete-returning") { "RETURNING *" => [] }
multi method translate($, "update-returning") { "RETURNING *" => [] }

multi method translate(Red::AST::Delete $_, $context?, :$gambi where !*.defined) {
    my Int $*bind-counter;
    my $*red-subselect-for = UPDATE;
    self.Red::Driver::CommonSQL::translate($_, $context, :gambi);
}

multi method translate(Red::AST::Insert $_, $context?) {
    my Int $*bind-counter;
    my @values = .values.grep({
        .value.value.defined || (.value.column.DEFINITE
            && .value.column.attr.type ~~ Json && !(.value.value === Json))
    });
    return "INSERT INTO { self.table-name-wrapper: .into.^table } "
        ~ "DEFAULT VALUES RETURNING *" => [] unless @values;
    my @bind = @values.map: { self.wildcard-value: .value };
    "INSERT INTO {
        self.table-name-wrapper: .into.^table
    }(\n{
        @values>>.key.join(",\n").indent: 3
    }\n)\nVALUES(\n{
        @values.map({
            my $placeholder = self.wildcard;
            .value.column.attr.type ~~ Json
                ?? "$placeholder\::text::jsonb" !! $placeholder
        }).join(",\n").indent: 3
    }\n) RETURNING *" => @bind
}

multi method translate(Red::AST::Mod $_, $context?) {
    my ($ls, @lb) := do given self.translate: .left,  $context { .key, .value }
    my ($rs, @rb) := do given self.translate: .right, $context { .key, .value }
    "mod($ls, $rs)" => [|@lb, |@rb]
}

multi method translate(Red::AST::Value $_ where .type ~~ Bool, $context?) {
    (.value ?? "TRUE" !! "FALSE") => []
}

multi method translate(Red::AST::Value $_ where .type ~~ UUID, $context?) { "'{ .value.Str }'" => [] }

multi method translate(Red::AST::Value $_ where .type ~~ Rat, $context?) {
    "'{ .value.Num }'::numeric" => []
}

multi method translate(Red::Column $_, "column-comment") {
    (.comment ?? qq[COMMENT ON COLUMN { self.translate: $_, "table-dot-column" } IS '{ .comment }'] !! "") => []
}

multi method translate(Red::Column $_, "column-type") {
    if .attr.type.?red-type-column-type -> $type { return self.type-by-name($type) => [] }
    if !.auto-increment && .attr.type =:= Mu && !.type.defined { return self.type-by-name("string") => [] }
    (.type.defined ?? self.type-by-name(.type) !! self.default-type-for: $_) => []
}

multi method translate(Red::AST::TableComment $_, $context?) { "COMMENT ON TABLE { .table } IS '{ .msg }'" => [] }

class Statement does Red::Statement {
    has Str $.query;
    method stt-exec($stt, *@bind) {
        $!driver.debug: $!query, @bind || @!binds;
        my $db = $stt ~~ DB::Pg ?? $stt.db !! $stt;
        my $sth = $db.prepare($!query);
        my $s = $sth.execute(|(@bind or @!binds));
        $db.finish if $stt ~~ DB::Pg;
        do if $s ~~ DB::Pg::Results { $s.hashes } else { [] }.iterator
    }
    method stt-row($stt) { $stt.pull-one }
}

method comment-on-same-statement { False }

multi method prepare(Str $query) {
    CATCH { default { self.map-exception($_).throw } }
    Statement.new: :driver(self), :statement($!dbh), :$query
}

multi method default-type-for(Red::Column $ where .auto-increment --> Str:D) { "serial" }

multi method default-type-for-type(Positional $_ --> Str:D) { "{ self.default-type-for-type: .of }[]" }
multi method default-type-for-type(Json          --> Str:D) { "jsonb" }
multi method default-type-for-type(DateTime      --> Str:D) { "timestamp" }
multi method default-type-for-type(Instant       --> Str:D) { "timestamp" }
multi method default-type-for-type(Date          --> Str:D) { "date" }
multi method default-type-for-type(Bool          --> Str:D) { "boolean" }
multi method default-type-for-type(Int           --> Str:D) { "integer" }
multi method default-type-for-type(Rat           --> Str:D) { "numeric" }
multi method default-type-for-type(UUID          --> Str:D) { "uuid" }
multi method default-type-for-type(Blob          --> Str:D) { "bytea" }
multi method default-type-for-type(Red::Column $ --> Str:D) { "varchar(255)" }

multi method type-for-sql("jsonb" --> "Json") {}

multi method inflate(Str $value, DateTime :$to!) { DateTime.new: $value }
multi method inflate(Blob $value, :$to!)         { $to.new: $value }
multi method deflate(Instant:D $value) { ~$value.DateTime.utc }
multi method deflate(DateTime:D $value) { ~$value.utc }

# CREATE UNIQUE INDEX reports SQLSTATE 23505 with a different message than
# INSERT/UPDATE. Preserve the same typed uniqueness error for existing data.
multi method map-exception(DB::Pg::Error::FatalError $x where {
    .state eq '23505' && .message.starts-with('could not create unique index')
}) {
    X::Red::Driver::Mapped::Unique.new:
        :driver<Pg>, :orig-exception($x), :fields[$x.constraint // '']
}

multi method map-exception(DB::Pg::Error::FatalError $x where .?message ~~ /"duplicate key value violates unique constraint " \"$<field>=(\w+)\"/) {
    X::Red::Driver::Mapped::Unique.new: :driver<Pg>, :orig-exception($x), :fields($<field>.Str)
}

multi method map-exception(DB::Pg::Error::FatalError $x where /"duplicate key value violates unique constraint"/) {
    $x.?message-detail ~~ /"Key (" \s* (\w+)+ % [\s* "," \s*] \s* ")=(" .*? ") already exists."/;
    my @fields = $0 ?? $0>>.Str !! "";
    X::Red::Driver::Mapped::Unique.new: :driver<Pg>, :orig-exception($x), :@fields,
}

multi method map-exception(DB::Pg::Error::FatalError $x where /"duplicate key value violates unique constraint"/) {
    $x.?message ~~ /"DETAIL:  Key (" \s* (\w+)+ % [\s* "," \s*] \s* ")=(" .*? ") already exists."/;
    X::Red::Driver::Mapped::Unique.new: :driver<Pg>, :orig-exception($x), :fields($0>>.Str)
}

multi method map-exception(DB::Pg::Error::FatalError $x where .?message ~~ /relation \s+ \"$<table>=(\w+)\" \s+ already \s+ exists/) {
    X::Red::Driver::Mapped::TableExists.new: :driver<Pg>, :orig-exception($x), :table($<table>.Str)
}

# PostgreSQL otherwise infers parameter-only UNION columns as text.
method product-value(Red::AST::Value:D $value) {
    my $translated = self.wildcard => [self.wildcard-value($value)];
    "CAST({ $translated.key } AS { self.default-type-for-type($value.returns) })"
        => $translated.value
}
