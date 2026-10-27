use nqp;
use Red::Attr::Column;
use Red::Attr::Relationship;
use Red::Type::Json;

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

has $!collection-snapshot-attr;

method collection-snapshot-attr(|) {
    $!collection-snapshot-attr;
}

sub collection-snapshot-attr-build(|) {
    {}
}

#| Deep-clones a collection, preserving container types (Array[Str], Hash[Int]...).
#| Immutable containers (List, Map, Set, Bag, Mix) and non-collection values
#| (scalars, type objects, Dates, Models) are returned as-is — safe because
#| they cannot be mutated in place.
my sub deep-clone(\v) {
    if v.DEFINITE && v ~~ Array {
        return v.WHAT.new: v.map({ deep-clone($_) }).List
    }
    if v.DEFINITE && v ~~ Hash {
        my \clone = v.WHAT.new;
        for v.kv -> $k, \val {
            clone.AT-KEY($k) = deep-clone(val)
        }
        return clone
    }
    v
}

#| True when the column can hold a collection-typed value.
#| Wide on purpose: `@.`/`%.` columns declare Positional/Associative constraints,
#| and Json columns declare Json. Immutable containers (List, Map, Set, Bag, Mix)
#| can flow through, but `deep-clone` returns them as-is — they cannot be
#| mutated in place, so a live reference is a safe snapshot for them.
my sub collection-column(Red::Attr::Column \col --> Bool) {
    so (col.type ~~ Positional
        || col.type ~~ Associative
        || col.type ~~ Json)
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
    if %attr<%!___COLLECTION_SNAPSHOT___> -> $a {
        $!collection-snapshot-attr //= $a;
    }
    else {
        $!collection-snapshot-attr = Attribute.new: :name<%!___COLLECTION_SNAPSHOT___>, :package(type), :type(Any), :!has_accessor;
        $!collection-snapshot-attr.set_build: &collection-snapshot-attr-build;
        type.^add_attribute: $!collection-snapshot-attr;
    }
}

submethod !TWEAK_pr(\instance: *%data) is rw {
    my @columns = instance.^columns;

    my %new = |@columns.map: {
        my Mu $built := .build;
        $built := $built.(self.WHAT, Mu) if $built ~~ Method;
        $built := .type.red-type-default
            if $built =:= Mu && .type.HOW ~~ Metamodel::ClassHOW
                && .type.^can("red-type-default");
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
            STORE => method (\value) is hidden-from-backtrace {
                die X::Assignment::RO.new(value => $col-data-attr.get_value(instance).{ col.column.attr-name }) unless col.rw;
                die X::TypeCheck::Assignment.new(symbol => col.name, got => value, expected => col.type) unless value =:= Nil || value ~~ col.type;
                if instance.^is-id: col {
                    instance.^set-id: col.name => value
                }
                instance.^set-dirty: col;
                $dirty-old-values-attr.get_value(instance).{ col.column.attr-name } =
                    collection-column(col)
                        ?? deep-clone($col-data-attr.get_value(instance).{ col.column.attr-name })
                        !! $col-data-attr.get_value(instance).{ col.column.attr-name };
                $col-data-attr.get_value(instance).{ col.column.attr-name } = value =:= Nil ?? col.type !! value # handle default
            }
        #use nqp;
        #nqp::bindattr(nqp::decont(instance), self.WHAT, col.name, proxy);
        col.set_value: instance<>, proxy
    }
    self.sync-collection-snapshots(instance);
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
        my $*RED-INTERNAL = True;
        my @columns = instance.^columns;

        my %new;
        for @columns -> $column {
            my Mu $built := $column.build;
            $built := $built.(self, Mu) if $built ~~ Method;
            $built := $column.type.red-type-default
                if $built =:= Mu && $column.type.HOW ~~ Metamodel::ClassHOW
                    && $column.type.^can("red-type-default");
            next if $built =:= Mu;
            if instance.^is-id: $column {
                instance.^set-id: $column.name => $built
            }
            %new{$column.column-attr-name} = $built;
        }

        for %data.kv -> $k, $v { %new{$k} = $v }


        my $col-data-attr         := self.^col-data-attr;
        for $col-data-attr.get_value(instance).kv -> $k, $v { %new{$k} = $v }

        my $dirty-old-values-attr := self.^dirty-old-values-attr;
        $col-data-attr.set_value: instance, %new;
        for @columns -> \col {
            my \proxy = Proxy.new:
                FETCH => method {
                    $col-data-attr.get_value(instance).{ col.column-attr-name }
                },
                STORE => method (\value) is hidden-from-backtrace {
                    my $attr-name = col.column-attr-name;
                    unless col.rw {
                        die X::Assignment::RO.new(
                            value => $col-data-attr.get_value(instance).{ $attr-name });
                    }
                    unless value =:= Nil || value ~~ col.type {
                        die X::TypeCheck::Assignment.new(
                            symbol => col.name, got => value, expected => col.type);
                    }
                    if instance.^is-id: col {
                        instance.^set-id: col.name => value
                    }
                    instance.^set-dirty: col;
                    my $data := $col-data-attr.get_value(instance);
                    $dirty-old-values-attr.get_value(instance).{ $attr-name } =
                        collection-column(col) ?? deep-clone($data{$attr-name}) !! $data{$attr-name};
                    $data{$attr-name} = value =:= Nil ?? col.type !! value
                }
            #use nqp;
            #nqp::bindattr(nqp::decont(instance), self.WHAT, col.name, proxy);
            col.set_value: instance<>, proxy
        }
        meta.sync-collection-snapshots(instance);
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
multi method set-dirty(\obj, Red::Attr::Column $attr) {
    $!dirty-cols-attr.get_value(obj).{$attr}++;
    Nil
}

multi method set-dirty(\obj, Set() $attr) {
    $!dirty-cols-attr.get_value(obj).{$_}++ for $attr.keys
}

multi method clean-up-columns(\obj, Set() $attr) {
    $!dirty-cols-attr.get_value(obj).{$_}-- for $attr.keys;
    # Re-sync collection snapshots for the cleaned columns, otherwise the next
    # `sync-collection-dirty` would see the refreshed value as a spurious change
    # (Refreshable case).
    my $data     := $!col-data-attr.get_value(obj);
    my $snapshot := $!collection-snapshot-attr.get_value(obj);
    my %by-name  := obj.^columns.map({ .column-attr-name => $_ }).Hash;
    for $attr.keys -> $key {
        my \col = %by-name{$key} // (obj.^columns.first: * === $key) // next;
        next unless col ~~ Red::Attr::Column && collection-column(col);
        my $col-key = col.column-attr-name;
        $snapshot{$col-key} = deep-clone($data{$col-key}) if $data{$col-key}:exists;
    }
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
    $!dirty-old-values-attr.set_value: obj, {};
    self.sync-collection-snapshots(obj);
}

#| Captures a deep-clone snapshot of every collection column's current value.
method sync-collection-snapshots(\obj) {
    my $data     := $!col-data-attr.get_value(obj);
    my $snapshot := $!collection-snapshot-attr.get_value(obj);
    for obj.^columns -> \col {
        next unless collection-column(col);
        my $key = col.column-attr-name;
        next unless $data{$key}:exists;
        $snapshot{$key} = deep-clone($data{$key});
    }
    Nil
}

#| Compares current collection values against snapshots and marks
#| divergent columns dirty, refreshing their snapshots.
method sync-collection-dirty(\obj) {
    my $data     := $!col-data-attr.get_value(obj);
    my $snapshot := $!collection-snapshot-attr.get_value(obj);
    for obj.^columns -> \col {
        next unless collection-column(col);
        my $key = col.column-attr-name;
        next unless ($data{$key}:exists) && ($snapshot{$key}:exists);
        unless $data{$key} eqv $snapshot{$key} {
            obj.^set-dirty: col;
            $snapshot{$key} = deep-clone($data{$key});
        }
    }
    Nil
}

multi method get-attr(\instance, Str $name) {
    $!col-data-attr.get_value(instance).{ $name }
}

multi method set-attr(\instance, Str $name, \value) {
    $!col-data-attr.get_value(instance).{ $name } = value
}

multi method get-attr(\instance, Red::Attr::Column $attr) {
    samewith instance, $attr.column-attr-name
}

multi method set-attr(\instance, Red::Attr::Column $attr, \value) {
    samewith instance, $attr.column-attr-name, value
}

multi method get-old-attr(\instance, Str $name) {
    $!dirty-old-values-attr.get_value(instance).{ $name }
}

multi method set-old-attr(\instance, Str $name, \value) {
    $!dirty-old-values-attr.get_value(instance).{ $name } = value
}

multi method get-old-attr(\instance, Red::Attr::Column $attr) {
    samewith instance, $attr.column-attr-name
}

multi method set-old-attr(\instance, Red::Attr::Column $attr, \value) {
    samewith instance, $attr.column-attr-name, value
}

