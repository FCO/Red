use Red::AST;
use Red::AST::Select;
use Red::Driver;
unit class Red::DoneResultSeq is Seq;

sub run-query(:$of, :$filter) {
}

class ResultSeq::Iterator does Iterator {
    has Mu:U        $.of            is required;
    has Red::AST    $.filter        is required;
    has Red::Driver $!driver        = $*RED-DB // die Q[$*RED-DB wasn't defined];
    has             $!st-handler;

    submethod TWEAK(|) {
        CATCH {
            default {
                .say;
                .rethrow
            }
        }
        my ($sql, @bind) := $!driver.translate: $!driver.optimize: Red::AST::Select.new: :$!of, :$!filter;
        if $*ENV<RED_DEBUG> {
            note "SQL : $sql";
            note "bind: @bind.perl()";
        }
        $!st-handler = $!driver.dbh.prepare: $sql;
        $!st-handler.execute: |@bind
    }

    method pull-one {
        my %data = $!st-handler.row: :hash;
        return IterationEnd unless %data;
        $!of.bless: |%data
    }
}

has Mu:U        $.of;
has Red::AST    $.filter;

method new(:$of, :$filter) {
    ::?CLASS.bless: :$of, :$filter
}

method iterator {
    ResultSeq::Iterator.new: :$!of, :$!filter
}
