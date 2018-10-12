use Red::AST;
use Red::Driver;
use Red::Driver::SQLite;
use Red::Statement;
use Red::Driver::CommonSQL;
unit class Red::Driver::Mock does Red::Driver::CommonSQL;

has Red::Driver $.driver-obj handles /./ = Red::Driver::SQLite.new;
has             @.should-return;
has Str         $.should-run;

class Statement does Red::Statement {
    has Iterator $.iterator;
    has Str      $.should-run;

    multi prepare-sql(Str:U $_) { Str }
    multi prepare-sql(Str:D $_) { .lc.subst(/\s+/, " ", :g).trim }

    method stt-exec($stt, *@bind) {
        my $should-run = $!should-run.&prepare-sql;
        my $runned     = $stt.&prepare-sql;
        die "waited for '$should-run' but tried to run '$runned'"
            if $!should-run.defined and $runned !~~ $should-run
    }
    method stt-row($stt) { $!iterator.pull-one }
}

multi method prepare(Red::AST $query) {
    my ($sql, @bind) := self.translate: self.optimize: $query;
    self.prepare: $sql;
}

multi method prepare(Str $query) {
    self.debug: $query;
    Statement.new: :driver(self), :statement($query), |(:$!should-run with $!should-run), :iterator(@!should-return.iterator)
}

