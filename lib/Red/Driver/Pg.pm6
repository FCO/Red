use DB::Pg;
use Red::Driver;
use Red::Driver::CommonSQL;
use Red::Statement;
use Red::AST::Infixes;
use X::Red::Exceptions;
use Red::AST::TableComment;
need UUID;

unit class Red::Driver::Pg does Red::Driver::CommonSQL;

has Str $!user;
has Str $!password;
has Str $!host;
has Int $!port;
has Str $!dbname;
has DB::Pg $!dbh;


submethod BUILD(DB::Pg :$!dbh, Str :$!user, Str :$!password, Str :$!host = "127.0.0.1", Int :$!port = 5432, Str :$!dbname) {
}

submethod TWEAK() {
    $!dbh //= DB::Pg.new: conninfo => "{ "user=$_" with $!user } { "password=$_" with $!password } { "host=$_" with $!host } { "port=$_" with $!port } { "dbname=$_" with $!dbname }";
}

multi method translate(Red::Column $_, "column-auto-increment") { "" => [] }

method wildcard { "\${ ++$*bind-counter }" }

multi method translate(Red::AST::Select $_, $context?) {
    my Int $*bind-counter;
    nextsame
}

multi method translate(Red::AST::Delete $_, $context?) {
    my Int $*bind-counter;
    nextsame
}

multi method translate(Red::AST::Insert $_, $context?) {
    my Int $*bind-counter;
    my @values = .values.grep({ .value.value.defined });
    my @bind = @values.map: *.value.get-value;
    "INSERT INTO {
        .into.^table
    }(\n{
        @values>>.key.join(",\n").indent: 3
    }\n)\nVALUES(\n{
        (self.wildcard xx @values).join(",\n").indent: 3
    }\n) RETURNING *" => @bind
}

multi method translate(Red::AST::Mod $_, $context?) {
    my ($ls, @lb) := self.translate: .left,  $context;
    my ($rs, @rb) := self.translate: .right, $context;
    "mod($ls, $rs)" => [|@lb, |@rb]
}

multi method translate(Red::AST::Value $_ where .type ~~ Bool, $context?) {
    (.value ?? "'t'" !! "'f'") => []
}

multi method translate(Red::AST::Value $_ where .type ~~ UUID, $context?) {
    "'{ .value.Str }'" => []
}

multi method translate(Red::Column $_, "column-comment") {
    (.comment ?? "COMMENT ON COLUMN { self.translate: $_, "table-dot-column" } IS '{ .comment }'" !! "") => []
}

multi method translate(Red::AST::TableComment $_, $context?) {
    "COMMENT ON TABLE { .table } IS '{ .msg }'" => []
}

class Statement does Red::Statement {
    has Str $.query;
    method stt-exec($stt, *@bind) {
        $!driver.debug: $!query, @bind || @!binds;
        my $s = $stt.query($!query, |(@bind or @!binds));
        do if $s ~~ DB::Pg::Results {
            $s.hashes
        } else {
            []
        }.iterator
    }
    method stt-row($stt) { $stt.pull-one }
}

multi method prepare(Red::AST $query) {
    do for |self.translate: self.optimize: $query -> Pair \data {
        my ($sql, @bind) := do given data { .key, .value }
        next unless $sql;
        do unless $*RED-DRY-RUN {
            my $stt = self.prepare: $sql;
            $stt.predefined-bind;
            $stt.binds = @bind.map: { self.deflate: $_ };
            $stt
        }
    }
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

multi method default-type-for(Red::Column $ where .attr.type ~~ DateTime                    --> Str:D) {"timestamp"}
multi method default-type-for(Red::Column $ where { .attr.type ~~ Int and .auto-increment } --> Str:D) {"serial"}
multi method default-type-for(Red::Column $ where .attr.type ~~ one(Int, Bool)              --> Str:D) {"integer"}
multi method default-type-for(Red::Column $ where .attr.type ~~ Bool                        --> Str:D) {"boolean"}
multi method default-type-for(Red::Column $ where .attr.type ~~ UUID                        --> Str:D) {"uuid"}
multi method default-type-for(Red::Column $                                                 --> Str:D) {"varchar(255)"}

multi method inflate(Str $value, DateTime :$to!) { DateTime.new: $value }

multi method map-exception(DB::Pg::Error::FatalError $x where /"duplicate key value violates unique constraint"/) {
    $x.message ~~ /"DETAIL:  Key (" \s* (\w+)+ % [\s* "," \s*] \s* ")=(" .*? ") already exists."/;
    X::Red::Driver::Mapped::Unique.new:
        :driver<Pg>,
        :orig-exception($x),
        :fields($0>>.Str)
}

multi method map-exception(DB::Pg::Error::FatalError $x where /"ERROR:"\s+ relation \s+ \"$<table>=(\w+)\" \s+ already \s+ exists\n/) {
    X::Red::Driver::Mapped::TableExists.new:
            :driver<Pg>,
            :orig-exception($x),
            :table($<table>.Str)
}