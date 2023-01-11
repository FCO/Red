use DB::Pg;
use Red::Driver;
use Red::Driver::CommonSQL;
use Red::Statement;
use Red::AST::Unary;
use Red::AST::Infixes;
use X::Red::Exceptions;
use Red::AST::TableComment;
use Red::Type::Json;
use Red::LockType;
need UUID;

unit class Red::Driver::Pg does Red::Driver::CommonSQL;

has Str $!user;
has Str $!password;
has Str $!host;
has Int $!port;
has Str $!dbname;
has $.dbh;


method schema-reader {}
#| Data accepted by the Pg driver constructor:
#| dbh     : DB::Pg object
#| user    : User to be used to connect to the database
#| password: Password to be used to connect to the database
#| host    : To be connected to
#| port    : What port to connect
#| dbname  : Database name
submethod BUILD(:$!dbh, Str :$!user, Str :$!password, Str :$!host = "127.0.0.1", Int :$!port = 5432, Str :$!dbname) {
}

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

method new-connection($dbh = $!dbh) {
    self.clone: dbh => $dbh
}

method begin {
    my $dbh = $!dbh.db;
    $dbh.begin;
    self.new-connection: $dbh
}

method commit {
    #die "Not in a transaction!" unless $*RED-TRANSCTION-RUNNING;
    $!dbh.commit.finish;
}

method rollback {
    #die "Deu ruim!!!";
    #die "Not in a transaction!" unless $*RED-TRANSCTION-RUNNING;
    $!dbh.rollback;
}

multi method translate(Red::AST::DateTimePart $_, $context?) {
    my ($sql, @bind) = do given self.translate: .base, $context { .key, |.value }
    "EXTRACT({ .part.key.uc } FROM { $sql })" => @bind # TODO: Make it better and use real function?
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

method wildcard { "\${ ++$*bind-counter }" }

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
        when "str" { "TEXT" }
        when "int" { "INTEGER" }
        when "num" { "NUMERIC" }
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


multi method translate(Red::Column $_, "column-auto-increment") {}

multi method translate(Red::AST::Select $_, $context?, :$gambi where !*.defined) {
    my $bind-counter = $*bind-counter // 0;
    {
        my Int $*bind-counter = $bind-counter;
        self.Red::Driver::CommonSQL::translate($_, $context, :gambi);
    }
}
multi method translate(Red::AST::Update $_, $context?, :$gambi where !*.defined) {
    my Int $*bind-counter;
    my $*red-subselect-for = UPDATE;
    self.Red::Driver::CommonSQL::translate($_, $context, :gambi);
}

multi method wildcard-value(@val) { @val.map: { self.wildcard-value: $_ } }
multi method wildcard-value($_ where { .HOW ~~ Metamodel::EnumHOW }) { .value }
multi method wildcard-value(Red::AST::Value $_) {
    self.wildcard-value: .get-value
}
multi method wildcard-value(Bool $_) { .Int }
multi method wildcard-value($_) { $_ }

multi method translate(Red::AST::RowId $_, $context?) { "OID" => [] }

multi method translate($, "delete-returning") {
    "RETURNING *" => []
}

multi method translate($, "update-returning") {
    "RETURNING *" => []
}

multi method translate(Red::AST::Delete $_, $context?, :$gambi where !*.defined) {
    my Int $*bind-counter;
    my $*red-subselect-for = UPDATE;
    self.Red::Driver::CommonSQL::translate($_, $context, :gambi);
}

multi method translate(Red::AST::Insert $_, $context?) {
    my Int $*bind-counter;
    my @values = .values.grep({ .value.value.defined });
    return "INSERT INTO { self.table-name-wrapper: .into.^table } DEFAULT VALUES RETURNING *" => [] unless @values;

    # TODO: User translation
    my @bind = @values.map: { self.wildcard-value: .value }
    "INSERT INTO {
        self.table-name-wrapper: .into.^table
    }(\n{
        @values>>.key.join(",\n").indent: 3
    }\n)\nVALUES(\n{
        (self.wildcard xx @values).join(",\n").indent: 3
    }\n) RETURNING *" => @bind
}

multi method translate(Red::AST::Mod $_, $context?) {
    my ($ls, @lb) := do given self.translate: .left,  $context { .key, .value }
    my ($rs, @rb) := do given self.translate: .right, $context { .key, .value }
    "mod($ls, $rs)" => [|@lb, |@rb]
}

multi method translate(Red::AST::Value $_ where .type ~~ Bool, $context?) {
    (.value ?? "'t'" !! "'f'") => []
}

multi method translate(Red::AST::Value $_ where .type ~~ UUID, $context?) {
    "'{ .value.Str }'" => []
}

multi method translate(Red::AST::Value $_ where .type ~~ Rat, $context?) {
    "'{ .value }'::{ self.default-type-for-type: .type }" => []
}


multi method translate(Red::Column $_, "column-comment") {
    (.comment ?? "COMMENT ON COLUMN { self.translate: $_, "table-dot-column" } IS '{ .comment }'" !! "") => []
}

multi method translate(Red::Column $_, "column-type")           {
    if .attr.type.?red-type-column-type -> $type {
        return self.type-by-name($type) => []
    }
    if !.auto-increment && .attr.type =:= Mu && !.type.defined {
        return self.type-by-name("string") => []
    }
    (.type.defined ?? self.type-by-name(.type) !! self.default-type-for: $_) => []
}

multi method translate(Red::AST::TableComment $_, $context?) {
    "COMMENT ON TABLE { .table } IS '{ .msg }'" => []
}

class Statement does Red::Statement {
    has Str $.query;
    method stt-exec($stt, *@bind) {
        $!driver.debug: $!query, @bind || @!binds;
        my $db = $stt ~~ DB::Pg ?? $stt.db !! $stt;
        my $sth = $db.prepare($!query);
        my $s = $sth.execute(|(@bind or @!binds));
        $db.finish if $stt ~~ DB::Pg;
        do if $s ~~ DB::Pg::Results {
            $s.hashes
        } else {
            []
        }.iterator
    }
    method stt-row($stt) { $stt.pull-one }
}

method comment-on-same-statement { False }

multi method prepare(Str $query) {
    CATCH {
        default {
            self.map-exception($_).throw
        }
    }
    Statement.new: :driver(self), :statement($!dbh), :$query
}

multi method default-type-for(Red::Column $ where .auto-increment --> Str:D) {"serial"}

multi method default-type-for-type(Positional $_ --> Str:D) {"{ self.default-type-for-type: .of }[]"}
multi method default-type-for-type(Json          --> Str:D) {"jsonb"}
multi method default-type-for-type(DateTime      --> Str:D) {"timestamp"}
multi method default-type-for-type(Instant       --> Str:D) {"timestamp"}
multi method default-type-for-type(Date          --> Str:D) {"date"}
multi method default-type-for-type(Bool          --> Str:D) {"boolean"}
multi method default-type-for-type(Int           --> Str:D) {"integer"}
multi method default-type-for-type(UUID          --> Str:D) {"uuid"}
multi method default-type-for-type(Blob          --> Str:D) {"bytea"}
multi method default-type-for-type(Red::Column $ --> Str:D) {"varchar(255)"}

multi method type-for-sql("jsonb"     --> "Json"    ) {}

multi method inflate(Str $value, DateTime :$to!) { DateTime.new: $value }
multi method inflate(Blob $value, :$to!)         { $to.new: $value }
multi method deflate(Instant:D  $value) { ~$value.DateTime.utc }
multi method deflate(DateTime:D $value) { ~$value.utc }

multi method map-exception(DB::Pg::Error::FatalError $x where .?message ~~ /"duplicate key value violates unique constraint " \"$<field>=(\w+)\"/) {
    X::Red::Driver::Mapped::Unique.new:
            :driver<Pg>,
            :orig-exception($x),
            :fields($<field>.Str)
}

multi method map-exception(DB::Pg::Error::FatalError $x where /"duplicate key value violates unique constraint"/) {
    $x.?message-detail ~~ /"Key (" \s* (\w+)+ % [\s* "," \s*] \s* ")=(" .*? ") already exists."/;
    my @fields = $0 ?? $0>>.Str !! "";
    X::Red::Driver::Mapped::Unique.new:
        :driver<Pg>,
        :orig-exception($x),
        :@fields,
}

multi method map-exception(DB::Pg::Error::FatalError $x where /"duplicate key value violates unique constraint"/) {
    $x.?message ~~ /"DETAIL:  Key (" \s* (\w+)+ % [\s* "," \s*] \s* ")=(" .*? ") already exists."/;
    X::Red::Driver::Mapped::Unique.new:
        :driver<Pg>,
        :orig-exception($x),
        :fields($0>>.Str)
}

multi method map-exception(DB::Pg::Error::FatalError $x where .?message ~~ /relation \s+ \"$<table>=(\w+)\" \s+ already \s+ exists/) {
    X::Red::Driver::Mapped::TableExists.new:
            :driver<Pg>,
            :orig-exception($x),
            :table($<table>.Str)
}
