use nqp;
use Red::Attr::Column;
use Red::Attr::Relationship;
unit role MetamodelX::Red::Dirtable;

has %.dirty-cols{Mu} is rw;
has $!col-data-attr;

method col-data-attr(|) {
    $!col-data-attr;
}

has $!dirty-cols-attr;

method dirty-cols-attr(|) {
    $!dirty-cols-attr;
}

sub col-data-attr-build(|){
    {}
}

sub dirty-cols-attr-build(|) {
    SetHash.new
}

method set-helper-attrs(Mu \type) {
    $!col-data-attr = Attribute.new: :name<%!___COLUMNS_DATA___>, :package(type), :type(Any), :!has_accessor;
    $!col-data-attr.set_build: &col-data-attr-build;
    type.^add_attribute: $!col-data-attr;
    $!dirty-cols-attr = Attribute.new: :name<%!___DIRTY_COLS_DATA___>, :package(type), :type(Any), :!has_accessor;
    $!dirty-cols-attr.set_build: &dirty-cols-attr-build;
    type.^add_attribute: $!dirty-cols-attr;
}

submethod !TWEAK_pr(\instance: *%data) {
    my @columns = instance.^columns.keys;

    my %new = |@columns.map: {
        my Mu $built := .build;
        $built := $built.(self.WHAT, Mu) if $built ~~ Method;
        next if $built =:= Mu;
        .column.attr-name => $built
    };

    for %data.kv -> $k, $v { %new{$k} = $v }

    my $col-data-attr := self.^col-data-attr;
    $col-data-attr.set_value: instance, %new;
    for @columns -> \col {
        my \proxy = Proxy.new:
            FETCH => method {
                $col-data-attr.get_value(instance).{ col.column.attr-name }
            },
            STORE => method (\value) {
                die X::Assignment::RO.new(value => $col-data-attr.get_value(instance).{ col.column.attr-name }) unless col.rw;
                instance.^set-dirty: col;
                $col-data-attr.get_value(instance).{ col.column.attr-name } = value
            }
        #use nqp;
        #nqp::bindattr(nqp::decont(instance), self.WHAT, col.name, proxy);
        col.set_value: instance<>, proxy
    }
    for self.^attributes -> $attr {
        with %data{ $attr.name.substr: 2 } {
            unless $attr ~~ Red::Attr::Column {
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
    state &build //= self.^find_private_method("TWEAK_pr");

    if self.declares_method(type, "TWEAK") {
        self.find_method(type, "TWEAK", :no_fallback(1)).wrap: &build;
    } else {
        self.add_method: type, "TWEAK", &build;
    }
}

multi method set-dirty(\obj, Set() $attr) {
    $!dirty-cols-attr.get_value(obj).{$_}++ for $attr.keys
}

method is-dirty(Any:D \obj)         { so $!dirty-cols-attr.get_value(obj) }
method clean-up(Any:D \obj)         { $!dirty-cols-attr.set_value(obj, SetHash.new) }
method dirty-columns(Any:D \obj)    { $!dirty-cols-attr.get_value(obj) }

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

