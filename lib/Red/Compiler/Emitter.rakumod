use Red::AST::RegexMatch;
use Red::AST::RegexCapture;
use Red::AST::RegexChars;
use Red::AST::IsDefined;
use Red::AST;
use Red::AST::Value;
use Red::AST::Infixes;
use Red::AST::Unary;
use Red::AST::IsDefined;
use Red::AST::Case;
use Red::AST::JsonItem;
use Red::AST::JsonOperation;
use Red::Projection;
use Red::Type::Json;
use Red::Compiler::Template;

#| Specialize query factories at CHECK time, without runtime opcode dispatch.
unit class Red::Compiler::Emitter;

method build(@plan --> Callable:D) {
    given @plan[0] {
        when 'inline-call' {
            my &arguments = self.build(@plan[3]);
            my &body = self.build(@plan[4]);
            return -> $template, $subject {
                arguments($template, $subject);
                body($template, $subject)
            };
        }
        when 'literal' {
            my $value = @plan[1];
            return -> $template, $subject { $value };
        }
        when 'capture' {
            my $index = @plan[1];
            return -> $template, $subject { $template.values[$index] };
        }
        when 'subject' {
            return -> $template, $subject {
                my $locals = try %*RED-COMPILER-LOCALS;
                $locals.DEFINITE && ($locals<topic>:exists) ?? $locals<topic> !! $subject
            };
        }
        when 'local' {
            my $index = @plan[1];
            return -> $template, $subject { %*RED-COMPILER-LOCALS{$index} };
        }
        when 'field' {
            my &parent = self.build(@plan[1]);
            my $name = @plan[2];
            return -> $template, $subject {
                my $value = parent($template, $subject);
                $template.unsupported("Unknown model member: $name")
                    unless $value ~~ ::('Red::Model') && !$value.DEFINITE
                        && ($value.^columns.first({ .name.substr(2) eq $name }).DEFINITE
                            || $value.^relationships.keys.first({ .name.substr(2) eq $name }).DEFINITE);
                $value."$name"()
            };
        }
        when 'index' {
            my &parent = self.build(@plan[1]);
            my $key = @plan[2];
            return -> $template, $subject {
                my $value = parent($template, $subject);
                if $value ~~ Red::AST && $value.returns ~~ Json {
                    $value = $value but ::('Red::ColumnMethods')
                        unless $value ~~ ::('Red::ColumnMethods');
                    $key ~~ Int ?? $value.AT-POS($key) !! $value.AT-KEY($key)
                } elsif $value ~~ Associative {
                    $template.unsupported("Unknown projected key: $key")
                        unless $value{$key}:exists;
                    $value{$key}
                } elsif $value ~~ Positional && $key ~~ Int && 0 <= $key < $value.elems {
                    $value[$key]
                } else {
                    $template.unsupported('The projected element does not support this index')
                }
            };
        }
        when 'sequence' {
            my @builders = @plan.skip(1).map({ self.build($_) });
            return -> $template, $subject {
                my $result;
                $result = $_($template, $subject) for @builders;
                $result
            };
        }
        when 'topic-assign' {
            my &value = self.build(@plan[1]);
            return -> $template, $subject {
                %*RED-COMPILER-LOCALS<topic> = value($template, $subject)
            };
        }
        when 'let' {
            my $index = @plan[1];
            my &value = self.build(@plan[2]);
            return -> $template, $subject {
                %*RED-COMPILER-LOCALS{$index} = value($template, $subject)
            };
        }
        when 'assign' {
            my @target = @plan[1].list;
            my &receiver = self.build(@target[1]);
            my &value = self.build(@plan[2]);
            if @target[0] eq 'field' {
                my $name = @target[2];
                return -> $template, $subject {
                    my $result = value($template, $subject);
                    receiver($template, $subject)."$name"() = $result;
                    $result
                };
            }
            my &key = @target[0] eq 'index'
                ?? self.build(['literal', @target[2]]) !! self.build(@target[2]);
            return -> $template, $subject {
                my $result = value($template, $subject);
                my $receiver = receiver($template, $subject);
                my $key = key($template, $subject);
                if $key ~~ Int || ($key ~~ Red::AST && $key.returns ~~ Int) {
                    $receiver.AT-POS($key) = $result;
                } else {
                    $receiver.AT-KEY($key) = $result;
                }
                $result
            };
        }
        when 'delete' {
            my &receiver = self.build(@plan[1]);
            my &key = self.build(@plan[2]);
            return -> $template, $subject {
                my $receiver = receiver($template, $subject);
                my $key = key($template, $subject);
                $receiver = $receiver but ::('Red::ColumnMethods')
                    unless $receiver ~~ ::('Red::ColumnMethods');
                $key ~~ Int || ($key ~~ Red::AST && $key.returns ~~ Int)
                    ?? $receiver.DELETE-POS($key) !! $receiver.DELETE-KEY($key)
            };
        }
        when 'lookup' | 'exists' {
            my &receiver = self.build(@plan[1]);
            my &key = self.build(@plan[2]);
            my $exists = @plan[0] eq 'exists';
            return -> $template, $subject {
                my $value = receiver($template, $subject);
                $template.unsupported('Dynamic indexing and existence require a JSON expression')
                    unless $value ~~ Red::AST && $value.returns ~~ Json;
                my $key = ast-value(key($template, $subject));
                $template.unsupported('A JSON index must be a string or integer expression')
                    unless $key.returns ~~ Str | Int;
                my $item = Red::AST::JsonItem.new($value, $key);
                $exists ?? Red::AST::JsonOperation.new(:operation<exists>, :value($item))
                    !! ($item but ::('Red::ColumnMethods'))
            };
        }
        when 'array' | 'list' {
            my @builders = @plan.skip(1).map({ self.build($_) });
            return @plan[0] eq 'array'
                ?? -> $template, $subject {
                    @builders.map({ $_($template, $subject).item }).Array
                }
                !! -> $template, $subject {
                    @builders.map({ $_($template, $subject).item }).List
                };
        }
        when 'hash' {
            my @keys = @plan.skip(1).map(*[0]);
            my @builders = @plan.skip(1).map({ self.build(.[1]) });
            return -> $template, $subject {
                @keys.kv.map(-> $i, $key { $key => @builders[$i]($template, $subject) }).Hash
            };
        }
        when 'string' {
            my @builders = @plan.skip(1).map({ self.build($_) });
            return -> $template, $subject {
                my @parts = @builders.map({
                    my $part = ast-value($_($template, $subject));
                    $part.returns ~~ Str ?? $part !! Red::AST::Cast.new($part, 'text')
                });
                my $result = @parts.shift // ast-value('');
                $result = Red::AST::Concat.new($result, $_) for @parts;
                $result
            };
        }
        when 'regex-guard' {
            my &value = self.build(@plan[1]);
            return -> $template, $subject {
                $template.unsupported('Regex variables require a literal SQL-compilable pattern', :fatal)
                    if value($template, $subject) ~~ Regex;
                $template.unsupported('Non-regex smartmatches use symbolic evaluation')
            };
        }
        when 'regex-chars' {
            my &value = self.build(@plan[1]);
            return -> $template, $subject {
                Red::AST::RegexChars.new(:value(value($template, $subject)))
            };
        }
        when 'regex-defined' {
            my &value = self.build(@plan[1]);
            return -> $template, $subject {
                Red::AST::IsDefined.new(value($template, $subject))
            };
        }
        when 'regex-value' {
            my &match = self.build(@plan[1]);
            my $selection = @plan[2];
            return -> $template, $subject {
                Red::AST::RegexCapture.new(:match(match($template, $subject)), :$selection)
            };
        }
        when 'regex' {
            my &value = self.build(@plan[1]);
            my $pattern = @plan[2];
            my @parameters = @plan.skip(3).map({ self.build($_) });
            return -> $template, $subject {
                my $bound = @parameters
                    ?? $pattern.instantiate(@parameters.map({ $_($template, $subject) }).List)
                    !! $pattern;
                Red::AST::RegexMatch.checked(ast-value(value($template, $subject)), $bound)
            };
        }
        when 'op' {
            my $type = ::('Red::AST::' ~ @plan[1]);
            my &left = self.build(@plan[2]);
            my &right = self.build(@plan[3]);
            my &comparison = @plan[5] ~~ Callable ?? @plan[5] !! Callable;
            my $membership = @plan[1] eq any(<In NotIn>);
            return -> $template, $subject {
                my $left = left($template, $subject);
                my $right = right($template, $subject);
                if &comparison.DEFINITE {
                    comparison($left, $right)
                } else {
                    $left = ast-value($left);
                    if $membership {
                        $right = $right.ast(:sub-select) if $right ~~ ::('Red::ResultSeq');
                        $right = $right.as-sub-select if $right ~~ ::('Red::AST::Select');
                    }
                    $type.new($left, ast-value($right))
                }
            };
        }
        when 'so' {
            my &value = self.build(@plan[1]);
            return -> $template, $subject {
                Red::AST::So.new(ast-value(value($template, $subject)))
            };
        }
        when 'not' {
            my &value = self.build(@plan[1]);
            return -> $template, $subject {
                Red::AST::Not.new(ast-value(value($template, $subject)))
            };
        }
        when 'negate' {
            my &value = self.build(@plan[1]);
            return -> $template, $subject {
                Red::AST::Mul.new(ast-value(-1), ast-value(value($template, $subject)))
            };
        }
        when 'call' {
            my $name = @plan[1];
            my &receiver = self.build(@plan[2]);
            my @builders = @plan.skip(3).map({ self.build($_) });
            return -> $template, $subject {
                my $value = receiver($template, $subject);
                my @args = @builders.map({ $_($template, $subject) });
                $value = $value but ::('Red::ColumnMethods')
                    if $value ~~ Red::AST && $value !~~ ::('Red::ColumnMethods');
                $value."$name"(|@args)
            };
        }
        when 'case' {
            my &condition = self.build(@plan[1]);
            my &yes = self.build(@plan[2]);
            my &no = self.build(@plan[3]);
            return -> $template, $subject {
                my $condition = ast-value(condition($template, $subject));
                my $yes = Red::Projection.from-value(yes($template, $subject));
                my $no = Red::Projection.from-value(no($template, $subject));
                $template.unsupported('Conditional projections must have the same shape')
                    unless $yes.signature eq $no.signature;
                my @no = $no.leaves;
                my @leaves = $yes.leaves.kv.map(-> $i, $value {
                    my Red::AST %when{Red::AST};
                    %when{$condition} = $value;
                    Red::AST::Case.new(:%when, :else(@no[$i]))
                });
                $yes.construct(@leaves)
            };
        }
        default {
            X::Red::Compiler::Unsupported.new(:reason('Unknown compiled query expression')).throw
        }
    }
}

method validator(@plan --> Callable:D) {
    return -> $template, $subject { Nil } if @plan[0] eq any(<literal capture local>);
    return self.build(@plan) if @plan[0] eq any(<subject field index>);
    if @plan[0] eq any(<lookup exists>) {
        my &receiver = self.build(@plan[1]);
        my &key = self.validator(@plan[2]);
        return -> $template, $subject {
            my $value = receiver($template, $subject);
            $template.unsupported('Dynamic indexing and existence require a JSON expression')
                unless $value ~~ Red::AST && $value.returns ~~ Json;
            key($template, $subject)
        };
    }
    my @children = @plan[0] eq 'hash'
        ?? @plan.skip(1).map(*[1]) !! @plan.skip(1).grep(* ~~ Array);
    my @validators = @children.map({ self.validator($_) });
    my &check = -> $template, $subject {
        $_($template, $subject) for @validators;
    };
    if @plan[0] eq 'topic-assign' {
        return -> $template, $subject {
            $template.unsupported('Only scalar projection parameters can be reassigned')
                unless $subject ~~ Red::AST;
            check($template, $subject)
        };
    }
    if @plan[0] eq 'assign' {
        my &target = @plan[1][0] eq any(<field index>)
            ?? self.build(@plan[1]) !! -> $template, $subject { Any };
        return -> $template, $subject {
            my $target = target($template, $subject);
            $template.unsupported('A read-only column cannot be updated')
                if $target ~~ ::('Red::Column') && !$target.attr.rw;
            check($template, $subject)
        };
    }
    &check
}
