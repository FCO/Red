use DBIish;
use Red::AST;
use Red::Driver;
use Red::Statement;
use Red::Driver::CommonSQL;
unit class Red::Driver::SQLite does Red::Driver::CommonSQL;

has $!database = q<:memory:>;
has $!dbh = DBIish.connect: "SQLite", :$!database;

class Statement does Red::Statement {
    method stt-exec($stt, *@bind) {
        $stt.execute: |@bind;
        $stt
    }
    method stt-row($stt) { $stt.row: :hash }
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
    Statement.new: :driver(self), :statement($!dbh.prepare: $query)
}

