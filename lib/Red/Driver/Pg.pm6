use DB::Pg;
use Red::Driver;
use Red::Driver::CommonSQL;
use Red::Statement;
use Red::AST::Infixes;
use X::Red::Exceptions;
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

multi method translate(Red::Column $_, "column-auto-increment") { Empty }

multi method translate(Red::AST::Insert $_, $context?) {
    my @values = .values.grep({ .value.value.defined });
    "INSERT INTO { .into.^table }(\n{ @values>>.key.join(",\n").indent: 3 }\n)\nVALUES(\n{ @values>>.value.map(-> $val { self.translate: $val, "insert" }).join(",\n").indent: 3 }\n) RETURNING *", []
}

multi method translate(Red::AST::Mod $_, $context?) {
    "mod({ self.translate: .left, $context }, { self.translate: .right, $context })"
}

multi method translate(Red::AST::Value $_ where .type ~~ Bool, $context?) {
    .value ?? "'t'" !! "'f'"
}

class Statement does Red::Statement {
    has Str $.query;
    method stt-exec($stt, *@bind) {
        my $s = $stt.query($!query, |@bind);
        do if $s ~~ DB::Pg::Results {
            $s.hashes
        } else {
            []
        }.iterator
    }
    method stt-row($stt) { $stt.pull-one }
}

multi method prepare(Red::AST $query) {
    my ($sql, @bind) := self.translate: self.optimize: $query;
    do unless $*RED-DRY-RUN {
        my $stt = self.prepare: $sql;
        $stt.predefined-bind;
        $stt.binds = @bind;
        $stt
    }
}

multi method prepare(Str $query) {
    self.debug: $query;
    Statement.new: :driver(self), :statement($!dbh), :$query
}

multi method default-type-for(Red::Column $ where .attr.type ~~ DateTime                    --> Str:D) {"timestamp"}
multi method default-type-for(Red::Column $ where { .attr.type ~~ Int and .auto-increment } --> Str:D) {"serial"}
multi method default-type-for(Red::Column $ where .attr.type ~~ one(Int, Bool)              --> Str:D) {"integer"}
multi method default-type-for(Red::Column $ where .attr.type ~~ Bool                        --> Str:D) {"boolean"}
multi method default-type-for(Red::Column $                                                 --> Str:D) {"varchar(255)"}

multi method inflate(Str $value, DateTime :$to!) { DateTime.new: $value }

multi method map-exception(DB::Pg::Error::FatalError $x where /"duplicate key value violates unique constraint"/) {
    $x.message ~~ /"DETAIL:  Key (" \s* (\w+)+ % [\s* "," \s*] \s* ")=(" .*? ") already exists."/;
    X::Red::Driver::Mapped::Unique.new:
        :driver<Pg>,
        :orig-exception($x),
        :fields($0>>.Str)
}
