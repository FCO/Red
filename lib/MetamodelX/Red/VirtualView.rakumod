unit role MetamodelX::Red::VirtualView;

method compose(Mu \type, |) {
  callsame;

  die "sql method is required for view models" unless type.^can("sql").defined
}
