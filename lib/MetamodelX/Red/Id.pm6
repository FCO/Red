use Red::Model;
use Red::AST::Value;
use Red::AST::Infixes;
use Red::Attr::Column;
unit role MetamodelX::Red::Id;

has $!id-values-attr;

method columns   { ... }
#method set-attr  { ... }
#method set-dirty { ... }

method id-values-attr(|) {
    $!id-values-attr;
}

sub id-values-attr-build(\type, | --> Hash){
    {}
}

method set-helper-attrs(Mu \type) {
    $!id-values-attr = Attribute.new: :name<%!___ID_VALUES___>, :package(type), :type(Hash), :!has_accessor;
    $!id-values-attr.set_build: &id-values-attr-build;
    type.^add_attribute: $!id-values-attr;
}

#| Returns if the given attr is an id
multi method is-id($, Red::Attr::Column $attr) {
    so $attr.column.id
}

multi method is-id($, $ --> False) {}

#| Gets a list of ids
method id(Mu \type) {
    self.columns(type).grep(*.column.id).list
}

#| get a list of ids and uniques
method general-ids(\model) {
    (|model.^id, |model.^unique-constraints)
}

#| Sets ids
method populate-ids(Red::Model:D $model) {
    $model.^reset-id;
    $model.^set-id: $model.^id.map({ .name => .get_value: $model }).Hash;
}

#| resets id
multi method reset-id(Red::Model:D $model) {
    $!id-values-attr.set_value: $model, {}
}

#| Sets ids
multi method set-id(Red::Model:D $model, %ids --> Hash()) {
    my %attrs = |$model.^id.map({ .name => $_ });
    for %ids.kv -> Str $name, $val {
        $!id-values-attr.get_value($model).{ $name } = $model.^get-attr: $name without $!id-values-attr.get_value($model).{ $name };
        self.set-attr: $model, $name, $val;
        $model.^set-dirty: %attrs{$name};
    }
}

#| Sets id
multi method set-id(Red::Model:D $model, $id where !.^isa: Associative --> Hash()) {
    my $col = $model.^id.head;
    $!id-values-attr.get_value($model).{ $col.name } = $model.^get-attr: $col without $!id-values-attr.get_value($model).{ $col.name };
    self.set-attr: $model, $col, $id;
    $model.^set-dirty: $col;
}

#| Returns a Hash with an id map
multi method id-map(Red::Model $model, $id --> Hash()) {
    die "$model.^name() has no id" unless $model.^id;
    $model.^id.head.name.substr(2) => $id
}

#| Returns a filter using the id
multi method id-filter(Red::Model:D $model) {
    $model.^general-ids.flat.map({
        Red::AST::Eq.new:
            .column,
            ast-value
                :type(.type),
                $!id-values-attr.get_value($model).{ .name }
                    // self.get-old-attr($model, $_)
                    // self.get-attr: $model, $_
    })
        .reduce: { Red::AST::AND.new: $^a, $^b }
}

#| Returns a filter using the id
multi method id-filter(Red::Model:U $model, $id) {
    die "Model must have only 1 id to use id-filter this way" if $model.^id.elems != 1;
    self.id-filter: $model, |{$model.^id.head.column.attr-name => $id}
}

# TODO: fix, $model.^general-ids can return an list of lists (for counstraints of more that one column)
#| Returns a filter using the id
multi method id-filter(Red::Model:U $model, *%data) { # where { .keys.all ~~ $model.^general-ids.flat.map(*.column.attr-name).any }) {
    my %cols := set $model.^general-ids.flat.map(*.column.attr-name);
    my @not-ids = %data.keys.grep: { not %cols{ $_ } };
    die "one of the following keys aren't ids: { @not-ids.join: ", " }" if @not-ids;
    $model.^general-ids.flat
        .map({
            next without %data{.column.attr-name};
            Red::AST::Eq.new:
                .column,
                ast-value %data{.column.attr-name}
        })
        .reduce: {
            Red::AST::AND.new: $^a, $^b
        }
    ;
}

#multi method id-filter(Red::Model:U $model, *%data) {
#    die "one of the following keys aren't ids: { %data.keys.join: ", " }"
#}

