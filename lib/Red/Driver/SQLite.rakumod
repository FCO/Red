use DBIish;
need DBDish::SQLite::Connection;
use Red::AST;
use Red::Driver;
use Red::Statement;
use Red::AST::Value;
use Red::AST::Select;
use Red::AST::Infixes;
use Red::AST::Function;
use Red::AST::DateTimeFuncs;
use Red::Driver::CommonSQL;
use Red::AST::LastInsertedRow;
use Red::AST::TableComment;
use Red::AST::JsonItem;
use Red::AST::JsonRemoveItem;
use Red::AST::JsonOperation;
use Red::AST::JsonSetItem;
use JSON::Fast;
use X::Red::Exceptions;
use UUID;
use Red::SchemaReader;
use Red::Driver::SQLite::SchemaReader;
use Red::Type::Json;
use Red::Projection;
use Red::Index;
unit class Red::Driver::SQLite does Red::Driver::CommonSQL;

has $.database = q<:memory:>;
has DBDish::SQLite::Connection $!dbh;

method schema-reader { Red::Driver::SQLite::SchemaReader }

method indexes-for-table(Str $table --> Array) {
    my @indexes;
    my $temporary = self.execute(
        'SELECT name FROM sqlite_temp_master WHERE type = \'table\' AND name = ?', $table).row;
    my $schema = $temporary ?? 'temp' !! 'main';
    my $catalog = $temporary ?? 'sqlite_temp_master' !! 'sqlite_master';
    my $statement = self.execute(
        'SELECT name, "unique", partial FROM pragma_index_list(?, ?)', $table, $schema);
    for self.index-catalog-rows($statement) -> $row {
        my $name = $row<name>;
        my $definition = self.execute(
            "SELECT sql FROM $catalog WHERE type = 'index' AND name = ? AND tbl_name = ?",
            $name, $table).row;
        my @keys;
        if $definition<sql>.defined {
            @keys = sql-index-keys($definition<sql>);
        } else {
            my $columns = self.execute(
                'SELECT name FROM pragma_index_info(?, ?) ORDER BY seqno', $name, $schema);
            for self.index-catalog-rows($columns) -> $column {
                @keys.push: self.table-name-wrapper($column<name>);
            }
        }
        @indexes.push: { :$name, :unique(so $row<unique>),
            :partial(so $row<partial>), :keys(@keys.Array) };
    }
    @indexes.Array
}

#| Data accepted by the SQLite driver constructor:
#| dbh     : DBDish::SQLite object
#| database: File name or C<:memory:> to a in memory DB (default)
submethod BUILD(DBDish::SQLite::Connection :$!dbh, Str :$!database = q<:memory:> ) {
}

submethod TWEAK() {
    $!dbh //= DBIish.connect: "SQLite", :$!database;
}

class Statement does Red::Statement {
    method stt-exec($stt, *@bind) {
        $.driver.debug: (@bind || @!binds);
        $stt.execute:  |(@bind || @!binds);
        $stt
    }
    method stt-row($stt) { $stt.row: :hash }
}

method stringify-json { True }

method offset-without-limit { -1 }

#| Begin transaction
method begin {
    self.prepare(Red::AST::BeginTransaction.new).map: *.execute;
    self
}

multi method prepare(Str $query) {
    CATCH {
        default {
            self.map-exception($_).throw
        }
    }
    self.debug: $query;
    Statement.new: :driver(self), :statement($!dbh.prepare: $query);
}

method create-schema(%models where .values.all ~~ Red::Model) {
    for %models.values -> $model {
        self.translate($_) for $model.^indexes;
    }
    do for %models.kv -> Str() $name, Red::Model $model {
        $name => $model.^create-table
    }
}

multi method join-type("outer") { die "'OUTER JOIN' is not supported by SQLite" }
multi method join-type("right") { die "'RIGHT JOIN' is not supported by SQLite" }

#| Does this driver accept drop table cascade?
multi method should-drop-cascade { False }

multi method translate(Red::AST::Value $_ where .type ~~ Bool, $context? where $_ ne "bind") {
    (.value ?? 1 !! 0) => []
}

multi method translate(Red::AST::DateTimeNow $_) { "CURRENT_TIMESTAMP" => [] }

multi method translate(Red::AST::Value $_ where { .type ~~ Json }, $context? where { !.defined || $_ ne "bind" }) {
    self.translate:
        Red::AST::Function.new(:func<JSON>, :args[ ast-value .value, :type(Str) ]),
        $context
}

multi method translate(Red::AST::Not $_ where { .value ~~ Red::Column and .value.attr.type !~~ Str }, $context?) {
    my ($val, @bind) := do given self.translate: .value, $context { .key, .value }
    "($val == 0 OR $val IS NULL)" => @bind
}

multi method translate(Red::AST::So $_ where { .value ~~ Red::Column and .value.attr.type !~~ Str }, $context?) {
    my ($val, @bind) := do given self.translate: .value, $context { .key, .value }
    "($val <> 0 AND $val IS NOT NULL)" => @bind
}

multi method translate(Red::AST::Not $_ where { .value ~~ Red::Column and .value.attr.type ~~ Str }, $context?) {
    my ($val, @bind) := do given self.translate: .value, $context { .key, .value }
    "($val == '' OR $val IS NULL)" => @bind
}

multi method translate(Red::AST::So $_ where { .value ~~ Red::Column and .value.attr.type ~~ Str }, $context?) {
    my ($val, @bind) := do given self.translate: .value, $context { .key, .value }
    "($val <> '' AND $val IS NOT NULL)" => @bind
}

multi method translate(Red::AST::RowId $_, $context?) { "_rowid_" => [] }

multi method translate(Red::AST::LastInsertedRow $_, $context?) {
    my $of     = .of;
    my $filter = Red::AST::Eq.new: Red::AST::RowId, Red::AST::Function.new: :func<last_insert_rowid>;
    self.translate(Red::AST::Select.new: :$of, :table-list[$of], :$filter, :1limit)
}

multi method translate(Red::Column $_, "column-auto-increment") { (.auto-increment ?? "AUTOINCREMENT" !! "") => [] }

multi method translate(Red::Column $_, "column-comment") {
    (" { self.comment-starter } $_\n" with .comment) => []
}

multi method translate(Red::AST::TableComment $_, $context?) {
        (" { self.comment-starter } { .msg }" => []) with $_
}

multi method translate(Red::AST::JsonRemoveItem $_, $context?) {
    my ($left, @lb) := do given self.translate(.left, $context) { .key, .value };
    my ($path, @pb) := do given self.sqlite-json-path(.right) { .key, .value };
    "JSON_REMOVE($left, $path)" => [|@lb, |@pb]
}

multi method translate(Red::AST::JsonItem $_, $context?) {
    my ($left, @lb) := do given self.translate(.left, "json-source") { .key, .value };
    my ($path, @pb) := do given self.sqlite-json-path(.right) { .key, .value };
    if $context.defined && $context eq any(<select json-value>) {
        # Keep serialized JSON at the inflation boundary, including scalar types.
        "(SELECT CASE WHEN kind IS NULL THEN NULL "
            ~ "WHEN kind IN ('true', 'false', 'null') THEN kind "
            ~ "WHEN kind IN ('object', 'array') THEN item "
            ~ "ELSE JSON_QUOTE(item) END FROM "
            ~ "(SELECT JSON_TYPE($left, $path) AS kind, "
            ~ "JSON_EXTRACT($left, $path) AS item))"
            => [|@lb, |@pb, |@lb, |@pb]
    } else {
        "JSON_EXTRACT($left, $path)" => [|@lb, |@pb]
    }
}

multi method translate(Red::AST::Value $_ where {
    .type ~~ Pair and .value.key ~~ Red::AST::JsonItem
}, "update") {
    my $item = .value.key;
    self.translate: ast-value($item.left => Red::AST::JsonSetItem.new(
        :left($item.left), :right($item.right), :value(.value.value))), "update"
}

method sqlite-json-path(Red::AST $path) {
    my @bind;
    my @sql = q['$'];
    for self.json-path-items($path) -> $item {
        if $item ~~ Red::AST::Value {
            my $part = $item.value ~~ Int
                ?? ($item.value < 0 ?? "[\#{ $item.value }]" !! "[{ $item.value }]")
                !! '.' ~ to-json($item.value.Str, :!pretty);
            @sql.push: self.wildcard;
            @bind.push: $part;
        } else {
            my ($sql, @values) := do given self.translate($item, "json-path") {
                .key, .value
            };
            if $item.returns ~~ Int {
                @sql.push: "('[' || CASE WHEN $sql < 0 THEN '#' ELSE '' END || $sql || ']')";
                @bind.append: |@values, |@values;
            } else {
                @sql.push: "('.' || JSON_QUOTE($sql))";
                @bind.append: @values;
            }
        }
    }
    '(' ~ @sql.join(' || ') ~ ')' => @bind
}

multi method translate(Red::AST::JsonSetItem $_, $context?) {
    my ($left, @lb) := do given self.translate(.left, $context) { .key, .value };
    my ($path, @pb) := do given self.sqlite-json-path(.right) { .key, .value };
    my ($value, @vb) := do given self.translate(.value, "json-value") { .key, .value };
    my $json-value = .value.returns ~~ Json ?? "JSON($value)"
        !! .value.returns ~~ Bool
            ?? "JSON((SELECT CASE WHEN v IS NULL THEN 'null' WHEN v THEN 'true' "
                ~ "ELSE 'false' END FROM (SELECT $value AS v)))"
            !! $value;
    "JSON_SET($left, $path, $json-value)" => [|@lb, |@pb, |@vb]
}

multi method translate(Red::AST::Value $_ where { .type ~~ Json }, "json-value") {
    self.wildcard => [self.wildcard-value($_)]
}

multi method translate(Red::AST::Value $_ where { .type ~~ Json }, "update-rval") {
    return "NULL" => [] if .value === Json;
    "JSON({ self.wildcard })" => [self.wildcard-value($_)]
}

multi method translate(Red::AST::JsonOperation $operation, $context?) {
    if $operation.operation eq "exists" {
        my $item = $operation.value;
        my ($left, @lb) := do given self.translate($item.left, $context) { .key, .value };
        my ($path, @pb) := do given self.sqlite-json-path($item.right) { .key, .value };
        return "(JSON_TYPE($left, $path) IS NOT NULL)" => [|@lb, |@pb];
    }
    my ($value, @bind) := do given self.translate($operation.value, "json-value") {
        .key, .value
    };
    given $operation.operation {
        when "elems" {
            my $presence = $operation.presence.DEFINITE ?? $operation.presence
                !! Red::Projection.json-presence($operation.value);
            my ($present, @pb) := self.translate($presence, $context).kv;
            "(SELECT CASE WHEN NOT j.present THEN 0 "
                ~ "WHEN JSON_TYPE(j.value) IN ('array', 'object') "
                ~ "THEN (SELECT count(*) FROM JSON_EACH(j.value)) ELSE 1 END "
                ~ "FROM (SELECT $value AS value, $present AS present) j)" => [|@bind, |@pb]
        }
        when "contains" {
            my ($argument, @ab) := do given self.translate($operation.argument, "json-value") {
                .key, .value
            };
            self.sqlite-json-contains($value, $argument) => [|@bind, |@ab]
        }
    }
}

#| Implements recursive JSON containment, with unordered array matching as in JSONB.
method sqlite-json-contains(Str $value, Str $argument --> Str) {
    qq:to/SQL/.trim;
    (WITH RECURSIVE
        actual AS (SELECT * FROM JSON_TREE($value)),
        wanted AS (
            SELECT *, row_number() OVER (ORDER BY id DESC) AS step
            FROM JSON_TREE($argument)
        ),
        matched(step, matches) AS (
            SELECT 0, JSON_OBJECT()
            UNION ALL
            SELECT wanted.step,
                JSON_SET(matched.matches, '\$."' || wanted.id || '"', JSON((
                    SELECT JSON_GROUP_ARRAY(a.id) FROM actual a
                    WHERE (a.type = wanted.type
                        OR (a.type IN ('integer', 'real')
                            AND wanted.type IN ('integer', 'real')))
                    AND CASE WHEN wanted.type IN ('object', 'array') THEN
                        NOT EXISTS (
                            SELECT 1 FROM wanted child
                            WHERE child.parent = wanted.id AND NOT EXISTS (
                                SELECT 1 FROM actual member
                                JOIN JSON_EACH(JSON_EXTRACT(matched.matches,
                                    '\$."' || child.id || '"')) found ON found.value = member.id
                                WHERE member.parent = a.id
                                AND (wanted.type = 'array' OR member.key = child.key)
                            )
                        )
                    ELSE a.atom IS wanted.atom END
                )))
            FROM matched JOIN wanted ON wanted.step = matched.step + 1
        )
        SELECT EXISTS (
            SELECT 1 FROM actual a
            JOIN JSON_EACH(JSON_EXTRACT(matches, '\$."' || root.id || '"')) found
                ON found.value = a.id
            WHERE a.parent IS NULL OR (root.type NOT IN ('object', 'array')
                AND a.parent = (SELECT id FROM actual WHERE parent IS NULL)
                AND (SELECT type FROM actual WHERE parent IS NULL) = 'array')
        ) FROM matched, wanted root
        WHERE root.parent IS NULL AND matched.step = (SELECT count(*) FROM wanted))
    SQL
}

multi method translate(Red::AST::Minus $ast, "multi-select-op") { "EXCEPT" => [] }

multi method translate(Red::LockType $lock-type --> Str ) {
    ''
}

method comment-on-same-statement { True }

#multi method default-type-for(Red::Column $ where .attr.type ~~ Mu             --> Str:D) {"varchar(255)"}
multi method default-type-for-type(Bool --> Str:D) {"integer"}
multi method default-type-for-type(Int  --> Str:D) {"integer"}
multi method default-type-for-type(UUID --> Str:D) {"varchar(36)"}
multi method default-type-for-type(Json --> Str:D) {"json"}
#multi method default-type-for(Red::Column $ where .attr.type ~~ Any             --> Str:D) {"varchar(255)"}
multi method default-type-for-type($ --> Str:D) is default {"varchar(255)"}

multi method inflate(Str $value, :@to!) {
    use JSON::Fast;
    do if @to.of =:= Mu {
        $value.&from-json
    } else {
        Array[@to.of].new: $value.&from-json
    }
}

multi method deflate(@value) {
    use JSON::Fast;
    @value.&to-json: :!pretty
}

multi method map-exception(X::DBDish::DBError $x where { (.?code == 19 or .?code == 1555 or .?code == 2067) and .native-message.starts-with: "UNIQUE constraint failed:" }) {
    X::Red::Driver::Mapped::Unique.new:
        :driver<SQLite>,
        :orig-exception($x),
        :fields($x.native-message.substr(26).split: /\s* "," \s*/)
}

multi method map-exception(X::DBDish::DBError $x where { .?code == 1 and .native-message ~~ m:i/^table \s+ $<table>=(\w+) \s+ already \s+ exists/ }) {
    X::Red::Driver::Mapped::TableExists.new:
            :driver<SQLite>,
            :orig-exception($x),
            :table($<table>.Str)
}

multi method map-exception(X::DBDish::DBError $x where { .?code == 1 and .native-message ~~ m:i/^table \s+ \"$<table>=(\w+)\" \s+ already \s+ exists/ }) {
    X::Red::Driver::Mapped::TableExists.new:
            :driver<SQLite>,
            :orig-exception($x),
            :table($<table>.Str)
}
