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

sub is-on-db-attr-build(\type, | --> Hash){
    {}
}

method set-helper-attrs(Mu \type) {
    $!id-values-attr = Attribute.new: :name<%!___ID_VALUES___>, :package(type), :type(Hash), :!has_accessor;
    $!id-values-attr.set_build: &is-on-db-attr-build;
    type.^add_attribute: $!id-values-attr;
}

multi method is-id($, Red::Attr::Column $attr) {
    so $attr.column.id
}

multi method is-id($, $ --> False) {}

method id(Mu \type) {
    self.columns(type).grep(*.column.id).list
}

method general-ids(\model) {
    (|model.^id, |model.^unique-constraints)
}

method populate-ids(Red::Model:D $model) {
    $model.^reset-id;
    $model.^set-id: $model.^id.map({ .name => .get_value: $model }).Hash;
}

multi method reset-id(Red::Model:D $model) {
    $!id-values-attr.set_value: $model, {}
}

multi method set-id(Red::Model:D $model, %ids --> Hash()) {
    my %attrs = |$model.^id.map({ .name => $_ });
    for %ids.kv -> Str $name, $val {
        $!id-values-attr.get_value($model).{ $name } = $model.^get-attr: $name without $!id-values-attr.get_value($model).{ $name };
        self.set-attr: $model, $name, $val;
        $model.^set-dirty: %attrs{$name};
    }
}

multi method set-id(Red::Model:D $model, $id where !.^isa: Associative --> Hash()) {
    my $col = $model.^id.head;
    $!id-values-attr.get_value($model).{ $col.name } = $model.^get-attr: $col without $!id-values-attr.get_value($model).{ $col.name };
    self.set-attr: $model, $col, $id;
    $model.^set-dirty: $col;
}

multi method id-map(Red::Model $model, $id --> Hash()) {
    $model.^id.head.name.substr(2) => $id
}

multi method id-filter(Red::Model:D $model) {
    $model.^id.map({ Red::AST::Eq.new: .column, ast-value :type(.type), $!id-values-attr.get_value($model).{ .name } // self.get-attr: $model, $_ })
        .reduce: { Red::AST::AND.new: $^a, $^b }
}

multi method id-filter(Red::Model:U $model, $id) {
    die "Model must have only 1 id to use id-filter this way" if $model.^id.elems != 1;
    self.id-filter: $model, |{$model.^id.head.column.attr-name => $id}
}

multi method id-filter(Red::Model:U $model, *%data where { .keys.all ~~ $model.^general-ids>>.name>>.substr(2).any }) {
    $model.^general-ids
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

multi method id-filter(Red::Model:U $model, *%data) {
    die "one of the following keys aren't ids: { %data.keys.join: ", " }"
}

