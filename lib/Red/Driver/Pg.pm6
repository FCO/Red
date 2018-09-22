use DB::Pg;
use Red::Driver;
use Red::Driver::CommonSQL;
use Red::Statement;
unit class Red::Driver::Pg does Red::Driver::CommonSQL;

has Str $!user;
has Str $!password;
has Str $!host = "127.0.0.1";
has Int $!port = 5432;
has Str $!dbname;
has $!dbh = DB::Pg.new: conninfo => "{ "user=$_" with $!user } { "password=$_" with $!password } { "host=$_" with $!host } { "port=$_" with $!port } { "dbname=$_" with $!dbname }";

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
    self does role :: { has $.predefined-bind = True }
    my ($sql, @bind) := self.translate: self.optimize: $query;
    do unless $*RED-DRY-RUN {
        my $stt = self.prepare: $sql;
        $stt.bind = @bind;
        $stt
    }
}

multi method prepare(Str $query) {
    Statement.new: :driver(self), :statement($!dbh), :$query
}

