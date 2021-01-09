use Red::Model;
use Red::DB;
unit role MetamodelX::Red::Supply;

method update-supply(::Model Red::Model:U \model, Supply $supply) {
	multi update(Model:D $model) {
		$model.^saved-on-db;
		$model.^clean-up-columns: $model.^id;
		$model.^save;
		# TODO: Generalise
		my %row = get-RED-DB.execute("SELECT changes() as changes;").row;
		unless %row<changes> {
			$model.^not-on-db;
			$model.^save;
		}
	}
	multi update(%model) {
		update Model.new: |%model;
	}
	$supply.tap: &update
}

method aggregate-supply(::Model Red::Model:U \model, Supply $supply, &func) {
	multi agg(Model:D $model) {
		$model.^all.map(&func.assuming: *, $model).save;
		# TODO: Generalise
		my %row = get-RED-DB.execute("SELECT changes() as changes;").row;
		unless %row<changes> {
			$model.^not-on-db;
			$model.^save;
		}
	}
	multi agg(%model) {
		agg Model.new: |%model;
	}
	$supply.tap: &agg
}
