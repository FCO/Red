use Red::AST;
use Red::Model;
use Red::Attr::Column;

=head2 MetamodelX::Red::Migration

unit role MetamodelX::Red::Migration;

my Callable    @migration-blocks;
my Pair        @migrations;

#| Creates a new migration for the model.
multi method migration(\model, &migr) {
    @migration-blocks.push: &migr
}

#| Add migrate method to composed models
method migrate(\model, Red::Model:U :$from!) {
    use MetamodelX::Red::MigrationHOW;
    
    my $migration-class = MetamodelX::Red::MigrationHOW.new_type(
        name => "{model.^name}-auto-migration",
        description => "Auto-generated migration from {$from.^name} to {model.^name}"
    );
    
    $migration-class.HOW.generate-from-models($from, model);
    $migration-class.HOW.execute-migration();
}

#| Prints the migrations.
method dump-migrations(|) {
    say "{ .key } => { .value.gist }" for @migrations
}
