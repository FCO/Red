use Red::DB;
use Red::Utils;
use Red::Cli::Table;
use Red::Cli::Column;
use Red::Model;

=head2 MetamodelX::Red::Describable

unit role MetamodelX::Red::Describable;

method !create-column($_ --> Red::Cli::Column) {
    Red::Cli::Column.new:
        :name(.column-name // self.column-formatter: .attr-name),
        :formated-name(.attr-name),
        :type(.type // get-RED-DB.default-type-for($_)),
        :perl-type(.type),
        :nullable(.nullable),
        :pk(.id),
        |(:references(%(table => .ref.attr.package.^table, column => .ref.name)) if .references)
}

#| Returns an object of type `Red::Cli::Table` that represents
#| a database table of the caller.
method describe(\model --> Red::Cli::Table) {
    my @constraints = model.^unique-constraints;
    Red::Cli::Table.new: :name(self.table(model)), :model-name(self.name(model)),
        :columns(self.columns>>.column.map({self!create-column($_)}).cache),
	:@constraints
}

#| Returns the difference to transform this model to the database version.
method diff-to-db(\model) {
    my Str $table = model.^table;
    my $b = $*RED-DB.schema-reader.table-definition: $table;
    model.^describe.diff: $b
}

#| Returns the difference to transform the DB table into this model.
method diff-from-db(\model) {
    $*RED-DB.schema-reader.table-definition(model.^table).diff: model.^describe
}

#| Returns the difference between two models.
multi method diff(\model, Red::Model \other-model) {
    model.^diff: other-model.^describe
}

#| Returns the difference between two models.
multi method diff(\model, Red::Cli::Table \other-model) {
    model.^describe.diff: other-model
}

#| Returns the difference between two models.
multi method diff(\model, \other-model) {
    model.^describe.diff: other-model
}
