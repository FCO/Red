use v6;
use Red::Model;
use Red::Attr::Column;
use Red::Column;
use Red::Utils;
use Red::ResultSeq;
use Red::DefaultResultSeq;
use Red::Attr::Query;
use Red::DB;
use Red::AST;
use Red::AST::Value;
use Red::AST::Insert;
use Red::AST::Delete;
use Red::AST::Update;
use Red::AST::Infixes;
use Red::AST::CreateTable;
use Red::AST::Constraints;
use Red::AST::TableComment;
use Red::AST::LastInsertedRow;
use MetamodelX::Red::Dirtable;
use MetamodelX::Red::Comparate;
use MetamodelX::Red::Migration;
use MetamodelX::Red::Relationship;
use MetamodelX::Red::OnDB;
use X::Red::Exceptions;
use Red::Phaser;

unit class MetamodelX::Red::Model is Metamodel::ClassHOW;
also does MetamodelX::Red::Dirtable;
also does MetamodelX::Red::Comparate;
#also does MetamodelX::Red::Migration;
also does MetamodelX::Red::Relationship;
also does MetamodelX::Red::OnDB;

has Attribute @!columns;
has Red::Column %!references;
has %!attr-to-column;
has $.rs-class;
has @!constraints;
has $.table;
has Bool $!temporary;

method column-names(|) { @!columns>>.column>>.name }

method constraints(|) { @!constraints.unique.classify: *.key, :as{ .value } }

method references(|) { %!references }

method table(Mu \type) { $!table //= camel-to-snake-case type.^name }
method as(Mu \type) { self.table: type }
method orig(Mu \type) { type.WHAT }
method rs-class-name(Mu \type) { "{type.^name}::ResultSeq" }
method columns(|) is rw {
    @!columns
}

method migration-hash(\model --> Hash()) {
    columns => @!columns>>.column>>.migration-hash,
    name    => model.^table,
    version => model.^ver // v0,
}

method id(Mu \type) {
    @!columns.grep(*.column.id).list
}

method id-values(Red::Model:D $model) {
    self.id($model).map({ .get_value: $model }).list
}

method default-nullable(|) is rw { $ //= False }

method unique-constraints(\model) {
    @!constraints.unique.grep(*.key eq "unique").map: *.value.attr
}

method general-ids(\model) {
    (|model.^id, |model.^unique-constraints)
}

multi method set-id(Red::Model:D $model, $id --> Hash()) {
    self.set-attr: $model, $model.^id.head, $id;
    $model.^set-dirty: $model.^id.head;
}

multi method id-map(Red::Model $model, $id --> Hash()) {
    $model.^id.head.name.substr(2) => $id
}

multi method id-filter(Red::Model:D $model) {
    $model.^id.map({ Red::AST::Eq.new: .column, Red::AST::Value.new: :value(self.get-attr: $model, $_), :type(.type) })
    .reduce: { Red::AST::AND.new: $^a, $^b }
}

multi method id-filter(Red::Model:U $model, $id) {
    die "Model must have only 1 id to use id-filter this way" if $model.^id.elems != 1;
    self.id-filter: $model, |{$model.^id.head.column.attr-name => $id}
}

multi method id-filter(Red::Model:U $model, *%data where { .keys.all ~~ $model.^general-ids>>.name>>.substr(2).any }) {
    $model.^general-ids
        .map({
            next without %data{.column.attr-name};
            Red::AST::Eq.new:
                .column,
                ast-value %data{.column.attr-name}
        })
        .reduce: {
            Red::AST::AND.new: $^a, $^b
        }
    ;
}

multi method id-filter(Red::Model:U $model, *%data) {
    die "one of the following keys aren't ids: { %data.keys.join: ", " }"
}

method attr-to-column(|) is rw {
    %!attr-to-column
}

method set-helper-attrs(Mu \type) {
    self.MetamodelX::Red::Dirtable::set-helper-attrs(type);
    self.MetamodelX::Red::OnDB::set-helper-attrs(type);
}

method compose(Mu \type) {
    self.set-helper-attrs: type;

    type.^prepare-relationships;

    if $.rs-class === Any {
        my $rs-class-name = $.rs-class-name(type);
        # TODO
        #my $rs-class = ::($rs-class-name);
        #if !$rs-class && $rs-class !~~ Failure  {
        #    $!rs-class = $rs-class;
        #} else {
            $!rs-class := create-resultseq($rs-class-name, type);
            type.WHO<ResultSeq> := $!rs-class
        #}
    }
    die "{$.rs-class.^name} should do the Red::ResultSeq role" unless $.rs-class ~~ Red::ResultSeq;
    self.add_role: type, Red::Model;
    self.add_role: type, role :: {
        method TWEAK(|) {
            self.^set-dirty: self.^columns
        }
    }
    my @roles-cols = self.roles_to_compose(type).flatmap(*.^attributes).grep: Red::Attr::Column;
    for @roles-cols -> Red::Attr::Column $attr {
        self.add-comparate-methods: type, $attr
    }

    type.^compose-columns;
    self.Metamodel::ClassHOW::compose(type);
    type.^compose-columns;

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
    my role RAlias[Red::Model:U \rtype, Str $rname] {
        method table(|) { rtype.^table }
        method as(|)    { camel-to-snake-case $rname }
        method orig(|)  { rtype }
    }
    alias.HOW does RAlias[type, $name];
    for @!columns -> $col {
        my $new-col = Attribute.new:
            :name($col.name),
            :package(alias),
            :type($col.type),
            :has_acessor($col.has_accessor),
            :build($col.build)
        ;
        $new-col does Red::Attr::Column($col.column.Hash);
        $new-col.create-column;
        alias.^add-comparate-methods: $new-col
    }
    for self.relationships.keys -> $rel {
        alias.^add-relationship: $rel
    }
    alias.^compose;
    alias
}

method add-column(::T Red::Model:U \type, Red::Attr::Column $attr) {
    if @!columns ∌ $attr {
        @!columns.push: $attr;
        my $name = $attr.column.attr-name;
        with $attr.column.references {
            self.add-reference: $name, $attr.column
        }
        self.add-comparate-methods(T, $attr);
        if $attr.has_accessor {
            if $attr.rw {
                T.^add_multi_method: $name, method (Red::Model:D:) is rw {
                    use nqp;
                    nqp::getattr(self, self.WHAT, $attr.name)
                }
            } else {
                T.^add_multi_method: $name, method (Red::Model:D:) {
                    $attr.get_value: self
                }
            }
        }
    }
}

method compose-columns(Red::Model:U \type) {
    for self.attributes(type).grep: Red::Attr::Column -> Red::Attr::Column $attr {
        $attr.create-column;
        type.^add-column: $attr
    }
}

method rs($)                        { $.rs-class.new }
method all($obj)                    { $obj.^rs }

method temp(|) is rw { $!temporary }

multi method create-table(\model, Bool :$if-not-exists where * === True) {
    CATCH { when X::Red::Driver::Mapped::TableExists {
        return False
    }}
    callwith model
}

multi method create-table(\model) {
    die X::Red::InvalidTableName.new: :table(model.^table)
        unless get-RED-DB.is-valid-table-name: model.^table
    ;
    get-RED-DB.execute:
        Red::AST::CreateTable.new:
            :name(model.^table),
            :temp(model.^temp),
            :columns[|model.^columns.map(*.column)],
            :constraints[
                |@!constraints.unique.map: {
                    when .key ~~ "unique" {
                        Red::AST::Unique.new: :columns[|.value]
                    }
                    when .key ~~ "pk" {
                        Red::AST::Pk.new: :columns[|.value]
                    }
                }
            ],
            |(:comment(Red::AST::TableComment.new: :msg(.Str), :table(model.^table)) with model.WHY)
    ;
    True
}

method apply-row-phasers($obj, Mu:U $phase ) {
    for $obj.^methods.grep($phase) -> $meth {
        $obj.$meth();
    }
}

multi method save($obj, Bool :$insert! where * == True, Bool :$from-create ) {
    self.apply-row-phasers($obj, BeforeCreate) unless $from-create;
    my $ret := get-RED-DB.execute: Red::AST::Insert.new: $obj;
    $obj.^saved-on-db;
    $obj.^clean-up;
    self.apply-row-phasers($obj, AfterCreate) unless $from-create;
    $ret
}

multi method save($obj, Bool :$update! where * == True) {
    self.apply-row-phasers($obj, BeforeUpdate);
    my $ret := get-RED-DB.execute: Red::AST::Update.new: $obj;
    $obj.^saved-on-db;
    $obj.^clean-up;
    self.apply-row-phasers($obj, AfterUpdate);
    $ret
}

multi method save($obj) {
    do if $obj.^is-on-db {
        self.save: $obj, :update
    } else {
        self.save: $obj, :insert
    }
}

method create(\model, *%orig-pars) is rw {
    my $RED-DB = get-RED-DB;
    {
        my $*RED-DB = $RED-DB;
        my %relationships := set %.relationships.keys>>.name>>.substr: 2;
        my %pars;
        my %positionals;
        for %orig-pars.kv -> $name, $val {
            my \attr-type = model.^attributes.first(*.name.substr(2) eq $name).type;
            if %relationships{ $name } {
                if $val ~~ Positional && attr-type ~~ Positional {
                    %positionals{$name} = $val
                } elsif $val !~~ attr-type {
                    %pars{$name} = attr-type.^create: |$val
                } else {
                    %pars{$name} = $val
                }
            } else {
                %pars{$name} = $val
            }
        }
        my $obj = model.new: |%pars;
        self.apply-row-phasers($obj, BeforeCreate);
        my $data := $obj.^save(:insert, :from-create).row;

        for %positionals.kv -> $name, @val {
            $obj."$name"().create: |$_ for @val
        }
        self.apply-row-phasers($obj, AfterCreate);
        return-rw Proxy.new:
                STORE => -> | {
                    die X::Assignment::RO.new(value => $obj)
                },
                FETCH => {
                    $ //= do {
                        my $*RED-DB = $RED-DB;
                        my $obj;
                        if $data.defined and not $data.elems {
                            $obj = model.new: |$*RED-DB.execute(Red::AST::LastInsertedRow.new: model).row
                        } else {
                            $obj = model.new: |$data
                        }
                        $obj.^saved-on-db;
                        $obj.^clean-up;
                        $obj
                    }
                }
        return $obj
    }
}

method delete(\model) {
    self.apply-row-phasers(model, BeforeDelete);
    get-RED-DB.execute: Red::AST::Delete.new: model ;
    self.apply-row-phasers(model, AfterDelete);
}

method load(Red::Model:U \model, |ids) {
    my $filter = model.^id-filter: |ids;
    model.^rs.grep({ $filter }).head
}

method new-with-id(Red::Model:U \model, |ids) {
    model.new: |model.^id-map: |ids;
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
