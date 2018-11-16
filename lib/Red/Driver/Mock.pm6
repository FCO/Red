use Test;
use Red::AST;
use Red::Driver;
use Red::Statement;
use Red::Driver::SQLite;
use Red::Driver::CommonSQL;
unit class Red::Driver::Mock does Red::Driver;

multi prepare-sql(Str:U $_) { Str }
multi prepare-sql(Str:D $_) {
    .lc
    .subst(/<[\w."']>+/, { " $_ " }, :g)
    .subst(/\s+/, " ", :g)
    .subst(
        /["(" \s*] ~ [\s* ")"] (<-[)]>+?)/,
        -> $/ {
            "( { $0.Str.split(/\s* "," \s*/).sort.join(", ") } )"
        },
        :g
    )
    .trim
}

has Hash        %.when-str{Str};
has Hash        %.when-re{Regex};
has Bool        $!die-on-unexpected = False;
has Red::Driver $.driver-obj = Red::Driver::SQLite.new;

multi method default-type-for(Red::Column $a --> Str:D) { $!driver-obj.default-type-for($a)     }
multi method is-valid-table-name(|c)                    { $!driver-obj.is-valid-table-name(|c)  }
multi method type-by-name(|c)                           { $!driver-obj.type-by-name(|c)         }
multi method inflate(|c)                                { $!driver-obj.inflate(|c)              }
method translate(|c)                                    { $!driver-obj.translate(|c)            }

class Statement does Red::Statement {
    has Iterator $.iterator;
    has Str      $.should-run;

    method stt-exec($stt, *@bind) { }
    method stt-row($stt) { $!iterator.pull-one }
}

method die-on-unexpected() {
  $!die-on-unexpected = True
}

proto method when(
    $when,
    Int  :$times,
    Bool :$once,
    Bool :$twice
) {
    my $*times = $times // ($once ?? 1 !! $twice ?? 2 !! Inf);
    {*};
    self
}

multi method when($when where Str | Regex, Bool :$never! where * === True) {
    self.when: $when, :run{ die "This should never be called" }, :0times;
}

multi method when(Str $when, :&run!) {
    %!when-str{$when.&prepare-sql} = {:&run, :$*times, :0counter};
}

multi method when(Regex $when, :&run!) {
    %!when-re{$when} = {:&run, :$*times, :0counter};
}

multi method when(Str $when, :@return!) {
    self.when: $when.&prepare-sql, :run{ @return }, :$*times;
}

multi method when(Regex $when, :@return!) {
    self.when: $when, :run{ @return }, :$*times;
}

multi method when(Str $when, :$throw!) {
    self.when: $when.&prepare-sql, :run{ die $throw }, :$*times;
}

multi method when(Regex $when, :$throw!) {
    self.when: $when, :run{ die $throw }, :$*times;
}

multi method prepare(Red::AST $query) {
    my ($sql, @bind) := self.translate: self.optimize: $query;
    self.prepare: $sql;
}

multi method prepare(Str $query) {
    my $t-query = $query.trans(("\n", "\t") => <␤ ␉>);
    self.debug: $query;
    given $query.&prepare-sql {
        with %!when-str{$_} -> % (:$times!, :$counter! is rw, :&run!) {
            $counter++;
            die "The query '$t-query' should never be called" unless $times;
            die "The query '$t-query' should run $times time(s) but was ran $counter times" if $counter > $times;
            return Statement.new: :driver(self), :iterator(run.iterator)
        }
        my $size = 0;
        my %data;
        for %!when-re.kv -> Regex $re, %value {
            if .match($re) && $/.Str.chars > $size {
                $size = $/.Str.chars;
                %data := %value;
            }
        }
        if %data {
            %data<counter>++;
            die "The query '$t-query' should never be called" unless %data<times> > 0;
            die "The query '$t-query' should run %data<times> time(s) but was ran %data<counter> times" if %data<counter> > %data<times>;
            return Statement.new: :driver(self), :iterator(%data<run>.().iterator)
        }

        flunk "Unexpected query: $_" if $!die-on-unexpected;
    }
    Statement.new: :driver(self), :iterator([].iterator)
}

method verify {
    subtest {
        plan %!when-str + %!when-re;
        for %!when-str.kv -> Str $str, % (:$counter = 0, :$times, |) {
            ok ($times == Inf or $counter == $times),
                "Query '$str' should be called $times times and was called $counter time(s)";
        }

        for %!when-re.kv -> Regex $re, % (:$counter = 0, :$times, |) {
            ok ($times == Inf or $counter == $times),
                "Query that matches '$re.perl()' should be called $times times and was called $counter time(s)";
        }
    }, "Red Mock verify"
}
