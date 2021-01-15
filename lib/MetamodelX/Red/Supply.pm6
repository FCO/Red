use Red::Model;
use Red::DB;
unit role MetamodelX::Red::Supply;

method last-state-of(::Model Red::Model:U \model, Supply $supply) {
	my Supplier $s .= new;
	multi update(Model:D $model) {
		try {
			$model.^saved-on-db;
			$model.^clean-up-columns: $model.^id;
			$model.^save;
		}
		# TODO: Generalise
		my %row = get-RED-DB.execute("SELECT changes() as changes;").row;
		unless %row<changes> {
			$model.^not-on-db;
			$model.^save;
		}
		$s.emit: $model
	}
	multi update(%model) {
		update Model.new: |%model;
	}
	$supply.tap: &update;
	$s.Supply
}

method transformed-state-of(::Model Red::Model:U \model, Supply $supply, &func) {
	my Supplier $s .= new;
	multi agg(Model:D $model) {
		try $model.^all.map(&func.assuming: *, $model).save;
		# TODO: Generalise
		my %row = get-RED-DB.execute("SELECT changes() as changes;").row;
		unless %row<changes> {
			$model.^not-on-db;
			$model.^save;
		}
		$s.emit: $model.^all.head
	}
	multi agg(%model) {
		agg Model.new: |%model;
	}
	$supply.tap: &agg;
	$s.Supply
}
