use nqp;
use Red::Attr::Column;
use Red::Attr::Relationship;

=head2 MetamodelX::Red::Dirtable

unit role MetamodelX::Red::Dirtable;

has %.dirty-cols{Mu} is rw;
has $!col-data-attr;

method col-data-attr(|) {
    $!col-data-attr;
}

sub col-data-attr-build(|){
    {}
}

has $!dirty-cols-attr;

method dirty-cols-attr(|) {
    $!dirty-cols-attr;
}

sub dirty-cols-attr-build(|) {
    SetHash.new
}

has $!dirty-old-values-attr;

method dirty-old-values-attr(|) {
    $!dirty-old-values-attr;
}

sub dirty-old-values-attr-build(|) {
    {}
}

method set-helper-attrs(Mu \type) {
    my %attr = type.^attributes.map( -> $a { $a.name => $a }).Hash;
    if %attr<%!___COLUMNS_DATA___>  -> $a {
        $!col-data-attr //= $a;
    }
    else {
        $!col-data-attr = Attribute.new: :name<%!___COLUMNS_DATA___>, :package(type), :type(Any), :!has_accessor;
        $!col-data-attr.set_build: &col-data-attr-build;
        type.^add_attribute: $!col-data-attr;
    }
    if %attr<%!___DIRTY_COLS_DATA___> -> $a {
        $!dirty-cols-attr //= $a;
    }
    else {
        $!dirty-cols-attr = Attribute.new: :name<%!___DIRTY_COLS_DATA___>, :package(type), :type(Any), :!has_accessor;
        $!dirty-cols-attr.set_build: &dirty-cols-attr-build;
        type.^add_attribute: $!dirty-cols-attr;
    }
    if %attr<%!___DIRTY_OLD_DATA___> -> $a {
        $!dirty-old-values-attr //= $a;
    }
    else {
        $!dirty-old-values-attr = Attribute.new: :name<%!___DIRTY_OLD_DATA___>, :package(type), :type(Any), :!has_accessor;
        $!dirty-old-values-attr.set_build: &dirty-old-values-attr-build;
        type.^add_attribute: $!dirty-old-values-attr;
    }
}

submethod !TWEAK_pr(\instance: *%data) is rw {
    my @columns = instance.^columns;

    my %new = |@columns.map: {
        my Mu $built := .build;
        $built := $built.(self.WHAT, Mu) if $built ~~ Method;
        next if $built =:= Mu;
        if instance.^is-id: $_ {
            instance.^set-id: .name => $built
        }
        .column.attr-name => $built
    };

    for %data.kv -> $k, $v { %new{$k} = $v }

    my $col-data-attr         := self.^col-data-attr;
    my $dirty-old-values-attr := self.^dirty-old-values-attr;
    $col-data-attr.set_value: instance, %new;
    for @columns -> \col {
        my \proxy = Proxy.new:
            FETCH => method {
                $col-data-attr.get_value(instance).{ col.column.attr-name }
            },
            STORE => method (\value) {
                die X::Assignment::RO.new(value => $col-data-attr.get_value(instance).{ col.column.attr-name }) unless col.rw;
                if instance.^is-id: col {
                    instance.^set-id: col.name => value
                }
                instance.^set-dirty: col;
                $dirty-old-values-attr.get_value(instance).{ col.column.attr-name } =
                    $col-data-attr.get_value(instance).{ col.column.attr-name };
                $col-data-attr.get_value(instance).{ col.column.attr-name } = value
            }
        #use nqp;
        #nqp::bindattr(nqp::decont(instance), self.WHAT, col.name, proxy);
        col.set_value: instance<>, proxy
    }
    for self.^attributes -> $attr {
        with %data{ $attr.name.substr: 2 } {
            unless $attr ~~ Red::Attr::Column {
                if self.^is-id: $attr {
                    self.^set-id: $attr.name => $_
                }
                $attr.set_value: self, $_
            }
        }
        # TODO: this should be on M::R::Relationship
        if $attr ~~ Red::Attr::Relationship {
            with %data{ $attr.name.substr: 2 } {
                $attr.set-data: instance, $_
            } else {
                my Mu $built := $attr.build;
                $built := $built.(self.WHAT, Mu) if $built ~~ Method;
                $attr.set-data: instance, $_ with $built
            }
        }
    }

    nextsame
}

method compose-dirtable(Mu \type) {
    my \meta = self;
    #state &build //= self.^find_private_method("TWEAK_pr");
    my &build = method (\instance: *%data) is rw {
        my @columns = instance.^columns;

        my %new = |@columns.map: {
            my Mu $built := .build;
            $built := $built.(self.WHAT, Mu) if $built ~~ Method;
            next if $built =:= Mu;
            if instance.^is-id: $_ {
                instance.^set-id: .name => $built
            }
            .column.attr-name => $built
        };

        for %data.kv -> $k, $v { %new{$k} = $v }


        my $col-data-attr         := self.^col-data-attr;
        for $col-data-attr.get_value(instance).kv -> $k, $v { %new{$k} = $v }

        my $dirty-old-values-attr := self.^dirty-old-values-attr;
        $col-data-attr.set_value: instance, %new;
        for @columns -> \col {
            my \proxy = Proxy.new:
                FETCH => method {
                    $col-data-attr.get_value(instance).{ col.column.attr-name }
                },
                STORE => method (\value) {
                    die X::Assignment::RO.new(value => $col-data-attr.get_value(instance).{ col.column.attr-name }) unless col.rw;
                    if instance.^is-id: col {
                        instance.^set-id: col.name => value
                    }
                    instance.^set-dirty: col;
                    $dirty-old-values-attr.get_value(instance).{ col.column.attr-name } =
                        $col-data-attr.get_value(instance).{ col.column.attr-name };
                    $col-data-attr.get_value(instance).{ col.column.attr-name } = value
                }
            #use nqp;
            #nqp::bindattr(nqp::decont(instance), self.WHAT, col.name, proxy);
            col.set_value: instance<>, proxy
        }
        for self.^attributes -> $attr {
            with %data{ $attr.name.substr: 2 } {
                unless $attr ~~ Red::Attr::Column {
                    if self.^is-id: $attr {
                        self.^set-id: $attr.name => $_
                    }
                    $attr.set_value: self, $_
                }
            }
            # TODO: this should be on M::R::Relationship
            if $attr ~~ Red::Attr::Relationship {
                with %data{ $attr.name.substr: 2 } {
                    $attr.set-data: instance, $_
                } else {
                    my Mu $built := $attr.build;
                    $built := $built.(self.WHAT, Mu) if $built ~~ Method;
                    $attr.set-data: instance, $_ with $built
                }
            }
        }

        nextsame
    }

    my role DirtableWrapped { };

    if self.declares_method(type, "TWEAK") {
        my &tweak = self.find_method(type, "TWEAK", :no_fallback(1));
        if &tweak !~~ DirtableWrapped {
            &tweak.wrap: &build;
            &tweak does DirtableWrapped;
        }
    } else {
        self.add_method: type, "TWEAK", &build;
    }
}

#| Accepts a Set of attributes of model and enables dirtiness flag for them,
#| which means that the values were changed and need a database sync.
multi method set-dirty(\obj, Set() $attr) {
    $!dirty-cols-attr.get_value(obj).{$_}++ for $attr.keys
}

multi method clean-up-columns(\obj, Set() $attr) {
    $!dirty-cols-attr.get_value(obj).{$_}-- for $attr.keys
}

#| Returns `True` if any of the object attributes were changed
#| from original database record values.
method is-dirty(Any:D \obj --> Bool) { so $!dirty-cols-attr.get_value(obj) }
#| Returns dirty columns of the object.
method dirty-columns(Any:D \obj)     { $!dirty-cols-attr.get_value(obj) }
#| Erases dirty status from all model's attributes, but does not (!)
#| revert their values to original ones.
method clean-up(Any:D \obj) {
    $!dirty-cols-attr.set_value: obj, SetHash.new;
    $!dirty-old-values-attr.set_value: obj, {}
}

multi method get-attr(\instance, Str $name) {
    $!col-data-attr.get_value(instance).{ $name }
}

multi method set-attr(\instance, Str $name, \value) {
    $!col-data-attr.get_value(instance).{ $name } = value
}

multi method get-attr(\instance, Red::Attr::Column $attr) {
    samewith instance, $attr.column.attr-name
}

multi method set-attr(\instance, Red::Attr::Column $attr, \value) {
    samewith instance, $attr.column.attr-name, value
}

multi method get-old-attr(\instance, Str $name) {
    $!dirty-old-values-attr.get_value(instance).{ $name }
}

multi method set-old-attr(\instance, Str $name, \value) {
    $!dirty-old-values-attr.get_value(instance).{ $name } = value
}

multi method get-old-attr(\instance, Red::Attr::Column $attr) {
    samewith instance, $attr.column.attr-name
}

multi method set-old-attr(\instance, Red::Attr::Column $attr, \value) {
    samewith instance, $attr.column.attr-name, value
}

