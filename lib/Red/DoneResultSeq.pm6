use Red::AST;
use Red::Driver;
use Red::Column;
use Red::AST::Select;
unit class Red::DoneResultSeq is Seq;

sub run-query(:$of, :$filter) {
}

class ResultSeq::Iterator does Iterator {
    has Mu:U        $.of            is required;
    has Red::AST    $.filter        is required;
    has Int         $.limit;
    has Red::Column @.order;
    has             &.post;
    has Red::Driver $!driver        = $*RED-DB // die Q[$*RED-DB wasn't defined];
    has             $!st-handler;

    submethod TWEAK(|) {
        CATCH {
            default {
                .say;
                .rethrow
            }
        }
        my ($sql, @bind) := $!driver.translate: $!driver.optimize: Red::AST::Select.new: :$!of, :$!filter, :$!limit, :@!order;

        unless $*RED-DRY-RUN {
            $!st-handler = $!driver.prepare: $sql;
            $!st-handler.execute: |@bind
        }
    }

    method pull-one {
        if $*RED-DRY-RUN { return $!of.bless }
        my $data := $!st-handler.row;
        return IterationEnd if $data =:= IterationEnd or not $data;
        my $obj = $!of.bless: |%$data;
        return .($obj) with &!post;
        $obj
    }
}

has Mu:U        $.of;
has Red::AST    $.filter;
has Int         $.limit;
has Red::Column @.order;
has             &.post;

method new(:$of, :$filter, Int :$limit, :&post, Red::Column :@order) {
    ::?CLASS.bless: :$of, :$filter, :$limit, :&post, :@order
}

method iterator {
    ResultSeq::Iterator.new: :$!of, :$!filter, :$!limit, :&!post, :@!order
}
