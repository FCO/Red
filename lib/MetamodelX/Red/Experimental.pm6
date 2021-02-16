unit role MetamodelX::Red::Experimental;

proto method experimental(|) {*}

multi method experimental("shortname", $obj) {
    $obj.^add_method: "experimental-name", method experimental-name(\model) { model.^shortname }
}

multi method experimental("formaters", $obj) {
    $obj.^mixin: role :: { method experimental-formater { True } }
    Red::Column.^add_method: "experimental-formater", method { True }
    Red::Column.^compose;
}

multi method experimental($ where "experimental migrations" | "migrations", $obj) {
    use MetamodelX::Red::Migration;
    $obj.^mixin: MetamodelX::Red::Migration;
}

multi method experimental("supply", $obj) {
    use MetamodelX::Red::Supply;
    $obj.^mixin: MetamodelX::Red::Supply;
}

multi method experimental("refreshable", $obj) {
    use MetamodelX::Red::Refreshable;
    $obj.^mixin: MetamodelX::Red::Refreshable;
}

multi method experimental($feature, $) {} # die "Experimental feature '{ $feature }' not recognized." }

multi method experimental(%exp) {
    self.experimental: $_, self for %exp;
}
