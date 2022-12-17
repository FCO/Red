unit role MetamodelX::Red::SubModelHOW is Metamodel::SubsetHOW;

sub __RED_OPERATOR_LOADED__ { True }

method all(\model, |c) { model.^refinee.^all(|c).grep: model.^refinement }

method load(\model, |ids) {
    my $filter = model.^refinee.^id-filter: |ids;
    model.^all.grep({ $filter }).head
}
method search(\model, |c) { model.^all.grep:   |c }
method create(\model, |c) { model.^all.create: |c }
method delete(\model, |c) { model.^all.delete: |c }
