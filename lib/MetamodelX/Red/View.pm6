unit role MetamodelX::Red::View;

method compose(Mu \type, |) {
  callsame;

  die "sql or select methods are required for view models" unless type.^can("sql").defined || type.^can("select").defined
}

