unit role MetamodelX::Red::PreFetch;

has %!pre-fetches;

method pre-fetches(\model) {
  model.^relationships.keys.grep: !*.no-prefetch
}
