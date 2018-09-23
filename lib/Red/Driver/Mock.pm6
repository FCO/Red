use DBIish;
use Red::AST;
use Red::Driver;
use Red::Statement;
use Red::Driver::CommonSQL;
unit class Red::Driver::Mock does Red::Driver::CommonSQL;

class Statement does Red::Statement {
    method stt-exec($stt, *@bind) {
        $stt
    }
    method stt-row($stt) { { :42data } }
}

multi method prepare(Red::AST $query) {
    my ($sql, @bind) := self.translate: self.optimize: $query;
    self.prepare: $sql;
}

multi method prepare(Str $query) {
    self.debug: $query;
    Statement.new: :driver(self)
}

