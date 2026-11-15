use Red::AST;
use Red::Model;
use Red::AST::Infixes;
use Red::AST::Value;
use Red::AST::Function;
use X::Red::Exceptions;

=head2 Red::ResultAssociative

#| Lazy Associative class from Red queries (.classify)
unit role Red::ResultAssociative[$of, Red::AST $key-of] does Associative;

has Red::AST    $!key-of = $key-of;
has             $.rs is required;
has             @.next-level;
has             &.reduce;

my role GroupSymbol {
    method unsupported {
        X::Red::Projection.new(:reason('Group rows must be consumed by SQL aggregates')).throw
    }
    method Array { self.unsupported }
    method List { self.unsupported }
    method Seq { self.unsupported }
    method list { self.unsupported }
    method iterator { self.unsupported }
    method Str { self.unsupported }
    method Numeric { self.unsupported }
    method Bool { self.unsupported }
    method elems { self.unsupported }
    method end { self.unsupported }
    method Int { self.unsupported }
    method Num { self.unsupported }
    method Rat { self.unsupported }
}

my class GroupValues does GroupSymbol {
    has Red::AST $.expression is required;

    method sum {
        Red::AST::Function.new(:func<SUM>, :args[$!expression], :returns($!expression.returns))
    }
    method min {
        Red::AST::Function.new(:func<MIN>, :args[$!expression], :returns($!expression.returns))
    }
    method max {
        Red::AST::Function.new(:func<MAX>, :args[$!expression], :returns($!expression.returns))
    }
}

my class GroupRows does GroupSymbol {
    has $.subject is required;

    method elems {
        Red::AST::Function.new(:func<COUNT>, :args[ast-value(*)], :returns(Int))
    }
    method map(&projection) {
        my $expression = ast-value(projection($!subject));
        X::Red::Projection.new(:reason('Group reductions require numeric SQL values')).throw
            unless $expression.returns ~~ Numeric;
        X::Red::Projection.new(:reason('Group reductions cannot use custom inflators')).throw
            if $expression.transpose-grep(-> $node {
                so $node.?custom-inflate || ($node ~~ Red::Column
                    && (so ($node.attr.?args // {})<inflate>:exists
                        || ($node.returns.HOW ~~ Metamodel::ClassHOW
                            && so $node.returns.^can('inflator'))))
            }).elems;
        GroupValues.new(:$expression)
    }
}

#| Project group keys and aggregates in SQL without enumerating the groups.
method map(&projection, :$red-ast) {
    my $fallback = !$*RED-FALLBACK.defined || so $*RED-FALLBACK;
    my $warn = !$*RED-FALLBACK.defined;
    CATCH {
        default {
            .rethrow unless $fallback;
            note "falling back: { .message }" if $warn;
            return self.Seq.map(&projection);
        }
    }
    X::Red::Projection.new(:reason('Nested and reduced groups require enumeration')).throw
        if @!next-level || &!reduce;
    {
        my $*RED-FALLBACK = False;
        my $*RED-DONT-FAIL-WITHOUT-OPERATORS = True;
        X::Red::Projection.new(:reason('Grouped projections require an unprojected source')).throw
            if $!rs.chain.projection.DEFINITE || $!rs.chain.source.DEFINITE
                || $!rs.limit.DEFINITE || $!rs.offset.DEFINITE;
        X::Red::Projection.new(:reason('Group key type requires native string formatting')).throw
            unless (Str, Int, UInt).map({ $_ =:= self.key-of }).any;
        my $input = $!rs.grep({ Red::AST::IsDefined.new($!key-of) });
        $input = $input.clone(:chain($input.chain.clone(:order([]))));
        my $key = self.key-of ~~ Numeric && !(self.key-of =:= Bool)
            # Keep the text conversion; Concat.new simplifies empty operands away.
            ?? Red::AST::Concat.Mu::new(:left(ast-value('')), :right($!key-of)) !! $!key-of;
        my $result = $input.map(-> $subject {
            projection($key => GroupRows.new(:subject($of)))
        });
        sub validate(Red::AST $expression) {
            return if $expression eqv $!key-of;
            return if $expression ~~ Red::AST::Function
                && $expression.func.uc eq any(<COUNT SUM MIN MAX>);
            X::Red::Projection.new(:reason('Ungrouped columns require an aggregate')).throw
                if $expression ~~ Red::Column;
            validate($_) for $expression.args.grep(Red::AST);
        }
        validate($_) for $result.chain.projection.leaves;
        $result.group = $!key-of;
        $result
    }
}

#| type of the value
method of     { $of }

#| type of the key
method key-of { $!key-of.returns }

sub __RED_OPERATOR_LOADED__ { True }

#| return a list of keys
#| run a SQL query to get it
method keys {
    if self.key-of ~~ Numeric && !(self.key-of =:= Bool) {
        my $keys = $!rs.map({
            Red::AST::Function.new(:func<DISTINCT>, :args[$key-of], :returns(self.key-of))
        });
        return gather for $keys.Seq { take .Str }
    }
    $!rs.map({ Red::AST::Function.new(:func<DISTINCT>, :args[$key-of], :returns(Str)) })
}

#| Run query to get the number of elements
method elems {
    $!rs.map({
        Red::AST::Function.new(:func<COUNT> :args[
            Red::AST::Function.new(:func<DISTINCT>, :args[$key-of], :returns(Int))
        ])
    }).head
}

#| return a ResultSeq for the given key
method AT-KEY($key) {
    my $value = $key;
    my Bool $valid = True;
    if self.key-of ~~ Numeric && !(self.key-of =:= Bool) && $key ~~ Str {
        my $number = try $key.Numeric;
        $valid = $number.DEFINITE && $number ~~ Numeric && $number.Str eq $key;
        $value = $number if $valid;
    }
    my \resultseq = $!rs.grep: {
        $valid ?? Red::AST::Eq.new($!key-of, ast-value($value), :bind-right)
            !! ast-value(False)
    }
    do if @!next-level {
        Red::ResultAssociative[$of, @!next-level.head].new: :rs(resultseq), |(:next-level(@!next-level.skip) if @!next-level.elems > 1), |(:&!reduce with &!reduce)
    } elsif &!reduce {
        &!reduce.(resultseq)
    } else {
        resultseq
    }
}

method iterator {
    gather for $.keys.Seq.grep: { .DEFINITE } { take $_ => self.AT-KEY: $_ }.iterator
}

method gist {
    "\{{self.map({ "{.key} => {.value.gist}" }).join: ", "}\}"
}

#| Run query to create a Bag
method Bag {
    my $rs = $!rs.map({ ($key-of, Red::AST::Function.new(:func<COUNT>, :args[ast-value("*"),], :returns(Int))) });
    $rs.group = $!key-of;
    $rs.Seq.map({ .[0] => .[1] }).Bag
}

#| Run query to create a Set
method Set {
    my $rs = $!rs.map({ Red::AST::Function.new(
        :func<DISTINCT>, :args[$key-of], :returns($key-of.returns)) });
    $rs.Seq.Set
}
