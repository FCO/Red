use Red::AST;
use Red::Driver;
use Red::Driver::SQLite;
use Red::Statement;
use Red::Driver::CommonSQL;
unit class Red::Driver::Mock does Red::Driver;

multi prepare-sql(Str:U $_) { Str }
multi prepare-sql(Str:D $_) { .lc.subst(/\s+/, " ", :g).trim }

#has Red::Driver $.driver-obj handles <
#    translate
#    prepare
#    default-type-for
#    is-valid-table-name
#    type-by-name
#    prepare
#    inflate
#> = Red::Driver::SQLite.new;
has Red::Driver $.driver-obj = Red::Driver::SQLite.new;
has Positional  %.when-str{Str};
has Positional  %.when-re{Regex};
has Positional  $.default-return is rw = [];

method translate(Red::AST $a, $b?)                  { $!driver-obj.translate($a, $b)        }
multi method prepare(|c)                            { $!driver-obj.prepare(|c)              }
multi method default-type-for(Red::Column $a)       { $!driver-obj.default-type-for($a)     }
multi method is-valid-table-name(|c)                { $!driver-obj.is-valid-table-name(|c)  }
multi method type-by-name(|c)                       { $!driver-obj.type-by-name(|c)         }
multi method prepare(|c)                            { $!driver-obj.prepare(|c)              }
multi method inflate(|c)                            { $!driver-obj.inflate(|c)              }

class Statement does Red::Statement {
    has Iterator $.iterator;
    has Str      $.should-run;

    method stt-exec($stt, *@bind) { }
    method stt-row($stt) { $!iterator.pull-one }
}

proto method when($, $?) {
    {*};
    self
}

multi method when(%pairs) {
    for %pairs.kv -> $k, $v {
        self.when: $k, $v
    }

}

multi method when(Str $when, @return) {
    %!when-str{$when.&prepare-sql} = @return;
}

multi method when(Regex $when, @return) {
    %!when-re{$when} = @return;
}

multi method prepare(Red::AST $query) {
    my ($sql, @bind) := self.translate: self.optimize: $query;
    self.prepare: $sql;
}

multi method prepare(Str $query) {
    self.debug: $query;
    given $query.&prepare-sql {
        with %!when-str{$_} {
            return Statement.new: :driver(self), :iterator(.iterator)
        }
        for %!when-re.kv -> Regex $re, @value {
            return Statement.new: :driver(self), :iterator(@value.iterator) if .match: $re
        }
    }
    Statement.new: :driver(self), :iterator($!default-return.iterator)
}

