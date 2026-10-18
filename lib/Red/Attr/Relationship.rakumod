use Red::AST::Reference;
use Red::AST;
use Red::AST::Infixes;
use Red::AST::Value;
use Red::HiddenFromSQLCommenting;
use X::Red::Exceptions;
use Red::Model;
use Red::DB;

my atomicint $creation-savepoint = 0;

unit role Red::Attr::Relationship[
	&rel1,
	&rel2?,
	Str         :$model,
	Str         :$require = $model,
	Bool        :$optional,
	Bool        :$no-prefetch,
	Bool        :$has-one,
    Mu:U        :$model-type = Red::Model,
];

has Mu:U $!type;
has Mu:U $!relationship-model;
has Bool $!loaded-model          = False;
has Bool $!optional              = $optional;
has Bool $.has-one               = $has-one;
has Bool $.no-prefetch           = $!has-one // $no-prefetch // self.type ~~ Positional;
has Str $.rel-name is rw;

method has-lazy-relationship { $model.DEFINITE || $model-type !=== Red::Model }

method transfer(Mu:U $package) {
    my $attr = Attribute.new: :$package, :$.name, :$.type;
    $attr but Red::Attr::Relationship[
        &rel1, &rel2, :$model, :$require, :$model-type, :$optional, :$no-prefetch, :$has-one
    ]
}

method !creation-type(\instance) {
    my role CreationContext[\origin, \relationship] {
        method create(Mu:U $, *%pars) {
            relationship.create-related(origin, |%pars)
        }
    }
    # Query aliases are cached, but a creation context owns one particular instance.
    my \context = self.target-type.^alias(
        :base(instance.WHAT), :relationship(self), :!cache
    );
    context.HOW does CreationContext[instance, self];
    context
}

method !creation-values(\instance) {
    my %values = self.relationship-ast(instance).should-set;
    X::Red::RelationshipCreate.new(:reason('referenced keys must have values')).throw
        unless %values && !%values.values.grep({ !.DEFINITE });
    %values
}

method create-related(\instance, :$with, *%pars) {
    my $*RED-INTERNAL = True;
    X::Red::RelationshipCreate.new(:reason('the source must be saved first')).throw
        unless instance.^is-on-db;
    X::Red::RelationshipCreate.new(:reason('the relationship must reference columns')).throw
        if &rel1.count > 1;
    my @columns = rel1(self.relationship-argument-type).flat;
    X::Red::RelationshipCreate.new(:reason('the relationship must reference columns')).throw
        unless @columns && @columns.all ~~ Red::Column;

    my $db = $with.DEFINITE
        ?? ($with ~~ Str ?? %GLOBAL::RED-DEFAULT-DRIVERS{$with} !! $with)
        !! get-RED-DB;
    my Bool $nested = so ($*RED-TRANSACTION-RUNNING && $db === get-RED-DB);
    my Str $savepoint = 'red_relationship_' ~ $creation-savepoint⚛++;
    my @state = (
        instance.^col-data-attr,
        instance.^dirty-cols-attr,
        instance.^dirty-old-values-attr,
        instance.^id-values-attr,
    ).map({ $_ => .get_value(instance).clone });
    my $transaction = $nested ?? $db !! $db.begin;
    $transaction.savepoint($savepoint) if $nested;
    {
        CATCH {
            default {
                my $cause = $_;
                .key.set_value(instance, .value) for @state;
                my Exception $cleanup;
                try {
                    if $nested {
                        $transaction.rollback-to-savepoint($savepoint);
                        $transaction.release-savepoint($savepoint);
                    } else {
                        $transaction.rollback;
                    }
                    CATCH { default { $cleanup = $_ } }
                }
                X::Red::Transaction::Cleanup.new(:$cause, :$cleanup).throw if $cleanup.DEFINITE;
                $cause.rethrow;
            }
        }
        my $*RED-DB = $transaction;
        my $*RED-TRANSACTION-RUNNING = True;
        my \target = self.target-type.^orig;
        my $created;
        if self.has-one {
            my %keys = self!creation-values(instance);
            $created = target.^create: |%pars, |%keys;
        } else {
            $created = target.^create: |%pars;
            my %keys = self!creation-values($created);
            for %keys.kv -> $name, $value {
                my $column = instance.^columns.first(*.column.attr-name eq $name);
                instance.^set-attr: $column, $value;
                instance.^set-dirty: $column;
            }
            instance.^save;
        }
        $nested ?? $transaction.release-savepoint($savepoint) !! $transaction.commit;
        $created
    }
}

method !to-use-with-rel {
    self.relationship-argument-type
}

method rel {
    CATCH {
        default {
            note "ERROR running relationship { self.name }: ", .message;
            .throw
        }
    }
    my $*RED-INTERNAL = True;
    my \type = self!to-use-with-rel;
    rel1 type
}

method relationship-model(--> Mu:U) is hidden-from-sql-commenting {
    return $model-type if $model-type !=== Red::Model;
    return self.type if !$model.DEFINITE && !$!loaded-model;
    unless $!loaded-model {
        my $t = ::($model);
        if !$t && $t ~~ Failure {
            require ::($require);
            $t = ::($model);
        }
        $!relationship-model := $t;
        $!loaded-model = True;
    }
    $!relationship-model
}

method set-data(\instance, Mu $value) is hidden-from-sql-commenting {
    do given $.rel {
        my $attr = .attr;
        my $ref  = .ref;
        $attr.set_value: instance, $ref.attr.get_value: $value;
        instance.^set-dirty: $attr;
    }
}

method build-relationship(\instance) is hidden-from-sql-commenting {
    my \type = self.type;
    my \attr = self;
    my \rel-model = self.target-type;
    use nqp;
    nqp::bindattr(nqp::decont(instance), $.package, $.name, Proxy.new:
        FETCH => method () {
            my $*RED-INTERNAL = True;
            my \ret = do if &rel1.count <= 1 {
                do if type ~~ Positional || attr.has-one {
                    my \relation = rel1(rel-model);
                    rel-model.^rs.where: relation.map(-> $rel {
                        X::Red::RelationshipNotColumn.new(
                            :relationship(attr),
                            :points-to($rel)
                        ).throw unless $rel ~~ Red::Column;

                        my $ref = $rel.ref;
                        X::Red::RelationshipNotRelated.new(
                            :relationship(attr),
                            :points-to($rel)
                        ).throw unless $ref.DEFINITE;

                        my $val = do given $ref.attr but role :: {
                            method package {
                                instance.WHAT
                            }
                        } {
                            instance.^get-attr: .name.substr: 2
                        }
                        my \value = ast-value $val;
                        Red::AST::Eq.new: $rel, value, :bind-right
                    }).reduce: -> $left, $right? {
                        $right.DEFINITE
                        ?? Red::AST::AND.new: $left, $right
                        !! $left
                    }
                } else {
                    my @columns = rel1(instance.WHAT).flat;
                    my @models = @columns.map(-> $rel {
                        my $val = $rel.attr.get_value: instance;
                        do with $val {
                            my \value = ast-value $val;
                            Red::AST::Eq.new: $rel.ref, value, :bind-right
                        }
                    }).grep(*.defined);
                    return attr!creation-type(instance) if @models.elems != @columns.elems;
                    rel-model.^rs.where(@models.reduce(-> $left, $right? {
                        $right.DEFINITE
                        ?? Red::AST::AND.new: $left, $right
                        !! $left
                    }))
                }
            } else {
                my $filter = instance.^all.join-model(:name(attr.name.substr: 2), rel-model, &rel1).ast.filter;
                # No point of running a query that should return no records...
                # Maybe it should be on driver
                if $filter ~~ Red::AST::Value && $filter.value.not {
                    return Nil
                }
                instance.^all.join-model: :name(attr.name.substr: 2), rel-model, &rel1;
            }
            if type !~~ Positional || attr.has-one {
                my $object = ret.head;
                return $object.DEFINITE ?? $object !! attr!creation-type(instance);
            }
	    ret
        },
        STORE => method ($value where type) {
            my $*RED-INTERNAL = True;
            die X::Assignment::RO.new(value => attr.type) unless attr.rw;
            if type !~~ Positional {
                attr.set-data: instance, $value
            } else {
                die "NYI Couldnt set value"
            }
        }
    );
    return
}

method target-type {
    my \model = self.relationship-model;
    model ~~ Positional ?? model.of !! model
}

method source-type {
    self.package
}

method relationship-argument-type {
    do if self.type ~~ Positional || self.has-one {
        $.target-type
    } else {
        $.source-type
    }
}

method joined-model {
	Empty.&return unless self.type ~~ Positional;
	self.package.^join: self.relationship-argument-type, -> | { self.relationship-ast: self.package }, name => self.rel-name
}

method !relationship-ast($t1, $t2) {
    my $*RED-INTERNAL = True;
    return rel1 $t1, $t2 if &rel1.count > 1;
    my \col1 = |rel1 $t1;
    return col1 if col1 ~~ Red::AST && col1 !~~ Red::Column | Red::AST::Reference;

    col1.map({
        X::Red::RelationshipNotColumn.new(
            :relationship(self),
            :points-to($_)
        ).throw unless $_ ~~ Red::Column
            || ($_ ~~ Red::AST::Reference && .origin ~~ Red::Column);

        Red::AST::Eq.new: $_, ast-value(.ref: $t2)
    }).reduce: -> $agg, $i? {
        return $agg without $i;
        Red::AST::AND.new: $agg, $i
    }
}

multi method relationship-ast($type, $oposite) is hidden-from-sql-commenting {
    self!relationship-ast($type, $oposite)
}
multi method relationship-ast($type = Nil) is hidden-from-sql-commenting {
    self!relationship-ast(self.relationship-argument-type, $type)
}

method join-type {
    my $*RED-INTERNAL = True;
    with $!optional {
        return $!optional ?? :left !! :inner
    }
    return :left if &rel1.count > 1;
    rel1(self.relationship-argument-type).flat.grep(*.?nullable) ?? :left !! :inner
}
