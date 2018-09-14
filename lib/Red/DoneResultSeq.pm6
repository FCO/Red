use Red::AST;
use Red::AST::Select;
use Red::Driver;
unit class Red::DoneResultSeq is Seq;

sub run-query(:$of, :$filter) {
}

class ResultSeq::Iterator does Iterator {
    has Mu:U        $.of            is required;
    has Red::AST    $.filter        is required;
    has Red::Driver $!driver        = $*RED-DB;
    has             $!st-handler;

    submethod TWEAK(|) {
        CATCH {
            default {
                .say;
                .rethrow
            }
        }
        my ($sql, @bind) = $!driver.translate: Red::AST::Select.new: :$!of, :$!filter;
        $!st-handler = $!driver.dbh.prepare: $sql;
        $!st-handler.execute #: |@bind
    }

    method pull-one {
        $!of.bless: |$!st-handler.row: :hash
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
