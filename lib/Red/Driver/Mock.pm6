use Red::AST;
use Red::Driver;
use Red::Driver::SQLite;
use Red::Statement;
use Red::Driver::CommonSQL;
unit class Red::Driver::Mock does Red::Driver;

multi prepare-sql(Str:U $_) { Str }
multi prepare-sql(Str:D $_) { .lc.subst(/\s+/, " ", :g).trim }

has Red::Driver $.driver-obj = Red::Driver::SQLite.new;
has Callable    %.when-str{Str};
has Callable    %.when-re{Regex};
has             &.default-return = { [] };

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

multi method default(:@return!) {
    &!default-return = { @return }
}

multi method default(:$throw!) {
    &!default-return = { die $throw }
}

proto method when($, $?) {
    {*};
    self
}

multi method when(Str $when, :&run!) {
    %!when-str{$when.&prepare-sql} = &run;
}

multi method when(Regex $when, :&run!) {
    %!when-re{$when} = &run;
}

multi method when(Str $when, :@return!) {
    self.when: $when.&prepare-sql, :run{ @return };
}

multi method when(Regex $when, :@return!) {
    self.when: $when, :run{ @return };
}

multi method when(Str $when, :$throw!) {
    self.when: $when.&prepare-sql, :run{ die $throw };
}

multi method when(Regex $when, :$throw!) {
    self.when: $when, :run{ die $throw };
}

multi method prepare(Red::AST $query) {
    my ($sql, @bind) := self.translate: self.optimize: $query;
    self.prepare: $sql;
}

multi method prepare(Str $query) {
    self.debug: $query;
    given $query.&prepare-sql {
        with %!when-str{$_} {
            return Statement.new: :driver(self), :iterator(.().iterator)
        }
        my $size = 0;
        my &re-value;
        for %!when-re.kv -> Regex $re, &value {
            if .match($re) && $/.Str.chars > $size {
                $size = $/.Str.chars;
                &re-value = &value;
            }
        }
        return Statement.new: :driver(self), :iterator(re-value.iterator) if $size
    }
    Statement.new: :driver(self), :iterator(&!default-return.().iterator)
}

