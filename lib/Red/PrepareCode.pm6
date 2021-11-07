use Red::AST;
use Red::AST::Unary;
use Red::AST::Infixes;
use Red::AST::Empty;
use Red::AST::Next;
use Red::AST::Value;
use CX::Red::Bool;

#| Transform a hash into filter (Red::AST)
sub hash-to-cond(%val) is export {
    my Red::AST $ast;
    for %val.kv -> Red::AST $cond, Bool $so {
        my Red::AST $filter = $so ?? Red::AST::So.new($cond) !! $cond.not;
        with $ast {
            $ast = Red::AST::AND.new: $ast, $filter
        } else {
            $ast = $filter
        }
    }
    $ast
}

#| Found a boolean while trying to find what's hapenning inside a block
sub found-bool(@values, $try-again is rw, %bools, CX::Red::Bool $ex) is export {
    if %bools{$ex.ast}:!exists {
        $try-again = True;
        %bools{ $ex.ast }++;
        if not @values {
            @values.push: [ :{ $ex.ast => $ex.value }, Red::AST ];
        } else {
            my @new-keys = @values.map: -> $item { my %key{Red::AST} = $item.[0].clone; %key{$ex.ast} = $ex.value.succ; %key };
            for @values {
                .[0].{$ex.ast} = $ex.value
            }
            @values.push: |@new-keys.map: -> %key { [ %key, Red::AST ] };
        }
    }
    $ex.resume
}

sub prepare-response($resp) is export {
    do given $resp {
        when Empty {
            Red::AST::Empty.new
        }
        when Red::AST {
            $_
        }
        default {
            ast-value $_
        }
    }
}

#| Tries to find what a block do
sub what-does-it-do(&func, \type --> Hash) is export {
    my Bool $try-again = False;
    my %bools is SetHash;
    my @values;
    my %*VALS := :{};

    my $ret = func type;
    return :{ Red::AST => prepare-response $ret } unless $try-again;
    @values.head.[1] = $ret;
    my %first-key := :{ @values.head.[0].keys.head.clone => @values.head.[0].values.head.clone };
    %first-key{ %first-key.keys.head } = True;
    @values.push: [%first-key, Red::AST];

    for @values -> @data (%values, $response is rw) {
        $try-again = False;
        %*VALS := %values;
        $response = func type;
        CONTROL {
            when CX::Next {
                $response = Red::AST::Next.new;
            }
            when CX::Red::Bool {                # Will work when we can create real custom CX
                found-bool @values, $try-again, %bools, $_
            }
        }
    }
    CONTROL {
        when CX::Red::Bool {                # Will work when we can create real custom CX
            found-bool @values, $try-again, %bools, $_
        }
        when CX::Next {
            die
        }
    }

    my Red::AST %values{Red::AST};
    for @values {
        %values{hash-to-cond(.[0])} = prepare-response .[1]
    }
    %values
}
