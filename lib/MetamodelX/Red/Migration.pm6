use Red::AST;
use Red::Model;
use Red::Attr::Column;
unit role MetamodelX::Red::Migration;

my Callable    @migration-blocks;
my Pair        @migrations;

multi method migration(\model, &migr) {
    @migration-blocks.push: &migr
}

multi method migrate(\model, Red::Model:U :$from) {
    my Red::Attr::Column %old-cols = $from.^columns.map: { .name.substr(2) => $_ };
    my Str               @new-cols = model.^columns.map: { .name.substr(2) };

    my \Type = Metamodel::ClassHOW.new_type: :name(model.^name);
    for (|%old-cols.keys, |@new-cols) -> $name {
        Type.^add_method: $name, method () is rw {
            Proxy.new:
                FETCH => method {
                    %old-cols{$name}.column
                },
                STORE => method (\data) {
                    @migrations.push: $name => data
                }
            ;
        }
    }

    Type.^compose;
    .(Type) for @migration-blocks
}

method dump-migrations(|) {
    say "{ .key } => { .value.gist }" for @migrations
}
