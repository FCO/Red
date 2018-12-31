use v6;
use Red::Model;
use Red::Attr::Column;
use Red::Column;
use Red::Utils;
use Red::ResultSeq;
use Red::DefaultResultSeq;
use Red::Attr::Query;
use Red::AST;
use Red::AST::Value;
use Red::AST::Insert;
use Red::AST::Delete;
use Red::AST::Update;
use Red::AST::Infixes;
use Red::AST::CreateTable;
use Red::AST::Constraints;
use Red::AST::LastInsertedRow;
use MetamodelX::Red::Dirtable;
use MetamodelX::Red::Comparate;
use MetamodelX::Red::Relationship;
use X::Red::InvalidTableName;

unit class MetamodelX::Red::Model is Metamodel::ClassHOW;
also does MetamodelX::Red::Dirtable;
also does MetamodelX::Red::Comparate;
also does MetamodelX::Red::Relationship;

has %!columns{Attribute};
has Red::Column %!references;
has %!attr-to-column;
has $.rs-class;
has @!constraints;

method constraints(|) { @!constraints.classify: *.key, :as{ .value } }

method references(|) { %!references }

method table(Mu \type) { camel-to-snake-case type.^name }
method as(Mu \type) { self.table: type }
method orig(Mu \type) { type.WHAT }
method rs-class-name(Mu \type) { "{type.^name}::ResultSeq" }
method columns(|) is rw {
    %!columns
}

method id(Mu \type) {
    %!columns.keys.grep(*.column.id).list
}

method id-values(Red::Model:D $model) {
    self.id($model).map({ .get_value: $model }).list
}

multi method default-nullable(|) { False }

multi method id-filter(Red::Model:D $model) {
    $model.^id.map({ Red::AST::Eq.new: .column, Red::AST::Value.new: :value(self.get-attr: $model, $_), :type(.type) })
    .reduce: { Red::AST::AND.new: $^a, $^b }
}

multi method id-filter(Red::Model:U $model, $id) {
    die "Model must have only 1 id to use id-filter this way" if $model.^id.elems != 1;
    self.id-filter: $model, |{$model.^id.head.column.attr-name => $id}
}

multi method id-filter(Red::Model:U $model, *%data) {
    $model.^id.map({ Red::AST::Eq.new: .column, Red::AST::Value.new: :value(%data{.column.attr-name}), :type(.type) })
    .reduce: { Red::AST::AND.new: $^a, $^b }
}

method attr-to-column(|) is rw {
    %!attr-to-column
}

method compose(Mu \type) {
    self.set-helper-attrs: type;

    type.^prepare-relationships;

    if $.rs-class === Any {
        my $rs-class-name = $.rs-class-name(type);
        if try ::($rs-class-name) !~~ Nil {
            $!rs-class = ::($rs-class-name)
        } else {
            $!rs-class := create-resultseq($rs-class-name, type);
            type.WHO<ResultSeq> := $!rs-class
        }
    }
    die "{$.rs-class.^name} should do the Red::ResultSeq role" unless $.rs-class ~~ Red::ResultSeq;
    self.add_role: type, Red::Model;
    type.^compose-columns;
    self.add_role: type, role :: {
        method TWEAK(|) {
            self.^set-dirty: self.^columns
        }
    }
    self.Metamodel::ClassHOW::compose(type);
    for type.^attributes -> $attr {
        %!attr-to-column{$attr.name} = $attr.column.name if $attr ~~ Red::Attr::Column:D;
    }

    self.compose-dirtable: type;

    if type.^constraints<pk>:!exists {
        type.^add-pk-constraint: type.^id>>.column if type.^id > 1
    }
}

method add-reference($name, Red::Column $col) {
    %!references{$name} = $col
}

method add-unique-constraint(Mu:U \type, &columns) {
    @!constraints.push: "unique" => columns(type)
}

multi method add-pk-constraint(Mu:U \type, &columns) {
    nextwith type, columns(type)
}

multi method add-pk-constraint(Mu:U \type, @columns) {
    @!constraints.push: "pk" => @columns
}

my UInt $alias_num = 1;
method alias(Red::Model:U \type, Str $name = "{type.^name}_{$alias_num++}") {
    my \alias = ::?CLASS.new_type(:$name);
    alias.HOW does role :: {
        method table(|) { type.^table }
        method as(|)    { camel-to-snake-case $name }
        method orig(|)  { type }
    }
    for %!columns.keys -> $col {
        alias.^add-comparate-methods: $col
    }
    for self.relationships.keys -> $rel {
        alias.^add-relationship: $rel
    }
    alias.^compose;
    alias
}

method add-column(Red::Model:U \type, Red::Attr::Column $attr) {
    %!columns ∪= $attr;
    my $name = $attr.column.attr-name;
    with $attr.column.references {
        self.add-reference: $name, $attr.column
    }
    type.^add-comparate-methods($attr);
    if $attr.has_accessor {
        if $attr.rw {
            type.^add_multi_method: $name, method (Red::Model:D:) is rw {
                use nqp;
                nqp::getattr(self, self.WHAT, $attr.name)
            }
        } else {
            type.^add_multi_method: $name, method (Red::Model:D:) {
                $attr.get_value: self
            }
        }
    }
}

method compose-columns(Red::Model:U \type) {
    for type.^attributes.grep: Red::Attr::Column -> Red::Attr::Column $attr {
        type.^add-column: $attr
    }
}

method rs($)                        { $.rs-class.new }
method all($obj)                    { $obj.^rs }

method create-table(\model) {
    die X::Red::InvalidTableName.new: :table(model.^table), :driver($*RED-DB.^name)
    unless $*RED-DB.is-valid-table-name: model.^table;
    $*RED-DB.execute:
        Red::AST::CreateTable.new:
            :name(model.^table),
            :columns[|model.^columns.keys.map(*.column)],
            :constraints[
                |@!constraints.grep(*.key eq "unique").map({
                    Red::AST::Unique.new: :columns[|.value]
                }),
                |@!constraints.grep(*.key eq "pk").map: {
                    Red::AST::Pk.new: :columns[|.value]
                },
            ]
}

multi method save($obj, Bool :$insert! where * == True) {
    my $ret := $*RED-DB.execute: Red::AST::Insert.new: $obj;
    $obj.^clean-up;
    $ret
}

multi method save($obj, Bool :$update where * == True = True) {
    my $ret := $*RED-DB.execute: Red::AST::Update.new: $obj;
    $obj.^clean-up;
    $ret
}

method create(\model, |pars) {
    my $obj = model.new: |pars;
    my $data := $obj.^save(:insert).row;
    if model.^id.elems and $data.defined and not $data.elems {
        $obj = model.new: |$*RED-DB.execute(Red::AST::LastInsertedRow.new: model).row
    } else {
        $obj = model.new: |$data
    }
    $obj.^clean-up;
    $obj
}

method delete(\model) {
    $*RED-DB. execute: Red::AST::Delete.new: model
}

method load(Red::Model:U \model, |ids) {
    my $filter = model.^id-filter: |ids;
    model.^rs.grep({ $filter }).head
}

multi method search(Red::Model:U \model, &filter) {
    model.^rs.grep: &filter
}

multi method search(Red::Model:U \model, Red::AST $filter) {
    samewith model, { $filter }
}

multi method search(Red::Model:U \model, *%filter) {
    samewith
        model,
        %filter.kv
            .map(-> $k, $value { Red::AST::Eq.new: model."$k"(), Red::AST::Value.new: :$value })
            .reduce: { Red::AST::AND.new: $^a, $^b }
}

method find(|c) { self.search(|c).head }

multi method get-attr(\instance, Str $name) {
    $!col-data-attr.get_value(instance).{ $name }
}

multi method set-attr(\instance, Str $name, \value) {
    $!col-data-attr.get_value(instance).{ $name } = value
}

multi method get-attr(\instance, Red::Attr::Column $attr) {
    samewith instance, $attr.column.attr-name
}

multi method set-attr(\instance, Red::Attr::Column $attr, \value) {
    samewith instance, $attr.column.attr-name, value
}
