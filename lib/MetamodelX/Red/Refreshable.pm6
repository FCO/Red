use Red::Model;
unit role MetamodelX::Red::Refreshable;

multi method refresh(Red::Model:D \model) {
	nextwith model, |model.^column-names
}

multi method refresh(Red::Model:D \model, +@attrs) {
	my %ans;
	%ans{ @attrs } = |model.^rs.map(-> $model { |@attrs.map: -> $attr { $model."$attr"() } }).head;
	for %ans.kv -> $attr, $value {
		model.^set-attr: $attr, $value
	}
	model.^clean-up-columns: @attrs;
	model
}
