use Red::AST;
use Red::Model;
use Red::Attr::Column;

=head2 MetamodelX::Red::Migration

unit role MetamodelX::Red::Migration;

my %migration-blocks;
my %migrations;

#| Register a symbolic transformation block for this model only. Registration does not execute
#| database statements; migrate collects the assignments produced by the registered blocks.
multi method migration(\model, &migr) {
    (%migration-blocks{model.WHICH.Str} //= []).push: &migr
}

#| Evaluate registered blocks against column proxies from the supplied historical model and
#| return their assignments. Each invocation collects fresh results without sharing other models'
#| blocks. This legacy API is distinct from the versioned migration.raku compiler.
multi method migrate(\model, Red::Model:U :$from) {
    my @assignments;
    my Red::Attr::Column %old-cols = $from.^columns.map: { .name.substr(2) => $_ };
    my Str               @new-cols = model.^columns.map: { .name.substr(2) };

    my \Type = Metamodel::ClassHOW.new_type: :name(model.^name);
    for (|%old-cols.keys, |@new-cols).unique -> $name {
        Type.^add_method: $name, method () is rw {
            Proxy.new:
                FETCH => method {
                    %old-cols{$name}.column
                },
                STORE => method (\data) {
                    @assignments.push: $name => data
                }
            ;
        }
    }

    Type.^compose;
    .(Type) for (%migration-blocks{model.WHICH.Str} // []).list;
    %migrations{model.WHICH.Str} = @assignments.Array;
    @assignments.Array
}

#| Print the assignments most recently collected for this model. Does not apply or persist them.
method dump-migrations(\model) {
    say "{ .key } => { .value.gist }" for (%migrations{model.WHICH.Str} // []).list
}
