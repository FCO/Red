use Red::DB;
use Red::Utils;
use Red::Cli::Table;
use Red::Cli::Column;

=head2 MetamodelX::Red::Describable

unit role MetamodelX::Red::Describable;

method !create-column($_ --> Red::Cli::Column) {
    Red::Cli::Column.new:
        :name(.column-name // kebab-to-snake-case .attr-name),
        :formated-name(.attr-name),
        :type(get-RED-DB.default-type-for($_)),
        :perl-type(.type),
        :nullable(.nullable),
        :pk(.id),
        |(:references(%(table => .ref.attr.package.^table, column => .ref.name)) if .references)
}

#| Returns an object of type `Red::Cli::Table` that represents
#| a database table of the caller.
method describe(\model --> Red::Cli::Table) {
    Red::Cli::Table.new: :name(self.table(model)), :model-name(self.name(model)),
        :columns(self.columns>>.column.map({self!create-column($_)}).cache)
}

#| Returns the difference to transform this model to the database version.
method diff-to-db(\model) {
    model.^describe.diff: $*RED-DB.schema-reader.table-definition: model.^table
}

#| Returns the difference to transform the DB table into this model.
method diff-from-db(\model) {
    $*RED-DB.schema-reader.table-definition(model.^table).diff: model.^describe
}

#| Returns the difference between two models.
method diff(\model, \other-model) {
    model.^describe.diff: other-model.^describe
}
