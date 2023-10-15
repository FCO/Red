use Red::AST::MultiSelect;
use Red::Column;
use Red::Attr::Column;
use Red::HiddenFromSQLCommenting;

unit role MetamodelX::Red::Specialisable;

multi method specialise($self, +@ret where .all ~~ Red::AST) is hidden-from-sql-commenting {
    my \Meta  = $self.^orig.HOW.WHAT;
    my \model = Meta.new(:table($self.^table)).new_type: :name($self.^name);
    model.HOW.^attributes.first(*.name eq '$!table').set_value: model.HOW, $self.^table;
    my $attr-name = 'data_0';
    my @attrs = do for @ret {
        @*table-list.push: |.tables if @*table-list.defined;
        my $name = $self.^all.filter ~~ Red::AST::MultiSelect ?? .attr.name.substr(2) !! ++$attr-name;
        my $col-name = $_ ~~ Red::Column ?? .name !! $name;
        my $attr  = Attribute.new:
            :name("\$!$name"),
            :package(model),
            :type(.returns ~~ Any && .returns !~~ Nil ?? .returns !! Any),
            :has_accessor,
            :build(.returns),
        ;
        my %data = %(
            :name-alias($col-name),
            :name($col-name),
            :attr-name($name),
            :type(.returns.^name),
            :$attr,
            :model(.tables.head),
            :class(model),
        	|(do if $_ ~~ Red::Column {
                :inflate(.inflate),
                :deflate(.deflate),
            } else {
                :computation($_)
            })
        );
        $attr does Red::Attr::Column(%data);
        model.^add_attribute: $attr;
        model.^add_multi_method: $name, my method (Mu:D:) { $self.^all.get_value: "\$!$name" }
        $attr
    }
    model.^add_method: "no-table", my method no-table { True }
    model.^add_method: "orig-result-seq", my method orig-result-seq { $self.^all }
    model.^compose;
    model.^add-column: $_ for @attrs;
    model
}
