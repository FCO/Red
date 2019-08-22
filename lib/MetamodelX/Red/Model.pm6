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
use MetamodelX::Red::Describable;
use MetamodelX::Red::OnDB;
use MetamodelX::Red::Id;
use X::Red::Exceptions;
use Red::Phaser;
use Red::Event;

=head2 MetamodelX::Red::Model

unit class MetamodelX::Red::Model is Metamodel::ClassHOW;
also does MetamodelX::Red::Dirtable;
also does MetamodelX::Red::Comparate;
#also does MetamodelX::Red::Migration;
also does MetamodelX::Red::Relationship;
also does MetamodelX::Red::Describable;
also does MetamodelX::Red::OnDB;
also does MetamodelX::Red::Id;

has Attribute @!columns;
has Red::Column %!references;
has %!attr-to-column;
has $.rs-class;
has @!constraints;
has $.table;
has Bool $!temporary;

multi method emit(Mu $model, Red::Event $event) {
    start try get-RED-DB.emit: $event.clone: :model($model.WHAT)
}

multi method emit(Mu $model, $data, Exception :$error, Red::Model :$origin) {
    self.emit: $model, Red::Event.new: :model($model.WHAT), |(:$data with $data), |(:$error with $error)
}

#| Returns a list of columns names.of the model.
method column-names(|) { @!columns>>.column>>.name }

#| Returns a hash of model constraints classified by type.
method constraints(|) { @!constraints.unique.classify: *.key, :as{ .value } }

#| Returns a hash of foreign keys of the model.
method references(|) { %!references }

#| Returns the table name for the model.
method table(Mu \type) is rw { $!table //= camel-to-snake-case type.^name }

#| Returns the table alias
method as(Mu \type) { self.table: type }

#| Returns the original model
method orig(Mu \type) { type.WHAT }

#| Returns the name of the ResultSeq class
method rs-class-name(Mu \type) { "{type.^name}::ResultSeq" }

#| Returns a list of columns
method columns(|) is rw {
    @!columns
}

#| Returns a hash with the migration hash
method migration-hash(\model --> Hash()) {
    columns => @!columns>>.column>>.migration-hash,
    name    => model.^table,
    version => model.^ver // v0,
}

#| Returns a liast of id values
method id-values(Red::Model:D $model) {
    self.id($model).map({ .get_value: $model }).list
}

#| Check if the model is nullable by default.
method default-nullable(|) is rw { $ //= False }

#| Returns all columns with the unique counstraint
method unique-constraints(\model) {
    @!constraints.unique.grep(*.key eq "unique").map: *.value>>.attr
}

#| A map from attr to column
method attr-to-column(|) is rw {
    %!attr-to-column
}

method set-helper-attrs(Mu \type) {
    self.MetamodelX::Red::Dirtable::set-helper-attrs(type);
    self.MetamodelX::Red::OnDB::set-helper-attrs(type);
    self.MetamodelX::Red::Id::set-helper-attrs(type);
}

#| Compose
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
        method TWEAK(|c) {
            self.^set-dirty: self.^columns;
            self.?TWEAK-MODEL(|c)
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

#| Creates a new reference (foreign key).
method add-reference($name, Red::Column $col) {
    %!references{$name} = $col
}

#| Creates a new unique constraint.
method add-unique-constraint(Mu:U \type, &columns) {
    @!constraints.push: "unique" => columns(type)
}

#| Creates a new primary key constraint.
multi method add-pk-constraint(Mu:U \type, &columns) {
    nextwith type, columns(type)
}

#| Creates the primary key constraint.
multi method add-pk-constraint(Mu:U \type, @columns) {
    @!constraints.push: "pk" => @columns
}

method tables(\model) { model }

my UInt $alias_num = 1;
method alias(Red::Model:U \type, Str $name = "{type.^name}_{$alias_num++}", :$base, :$relationship) {
    my \alias = ::?CLASS.new_type(:$name);
    my role RAlias[Red::Model:U \rtype, Str $rname, \alias, \rel, \base] {
        method table(|)   { rtype.^table }
        method as(|)      { camel-to-snake-case $rname }
        method orig(|)    { rtype }
        method join-on(|) { rel.relationship-ast(alias) }
        method tables(|)  { [ |base.^tables, alias ] }
    }
    alias.HOW does RAlias[type, $name, alias, $relationship, $base];
#    alias.^add_role: Red::Model;
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
        alias.^add-relationship: $rel.transfer: alias
    }
    alias.^compose;
    alias
}

#| Creates a new column and adds it to the model.
method add-column(::T Red::Model:U \type, Red::Attr::Column $attr) {
    if @!columns ∌ $attr {
        @!columns.push: $attr;
        my $name = $attr.column.attr-name;
        with $attr.column.references {
            self.add-reference: $name, $attr.column
        }
        self.add-comparate-methods(T, $attr);
        if $attr.has_accessor {
            if type.^rw or $attr.rw {
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

#| Returns the ResultSeq
multi method rs($ --> Red::ResultSeq)          { $.rs-class.new }
multi method rs($, :$with! --> Red::ResultSeq) { $.rs-class.new.with: $with }
#| Alias for C<.rs()>
multi method all($obj --> Red::ResultSeq)          { $obj.^rs }
multi method all($obj, :$with! --> Red::ResultSeq) { $obj.^rs(:$with) }

#| Sets model as a temporary table
method temp(|) is rw { $!temporary }


multi method create-table(Str :$with!, |c) {
    my $*RED-DB = %GLOBAL::RED-DEFULT-DRIVERS{$with};
    self.create-table: |c
}

multi method create-table(Red::Driver :$with!, |c) {
    my $*RED-DB = $with;
    self.create-table: |c
}

#| Creates table unless table already exists
multi method create-table(\model, Bool :unless-exists(:$if-not-exists) where ? *, *% where .keys.all ne "with") {
    CATCH {
        when X::Red::Driver::Mapped::TableExists {
            return False
        }
    }
    callwith model
}

#| Creates table
multi method create-table(\model, :$with where not .defined) {
    die X::Red::InvalidTableName.new: :table(model.^table)
        unless get-RED-DB.is-valid-table-name: model.^table
    ;
    my $data = Red::AST::CreateTable.new:
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
    get-RED-DB.execute: |$data;
    self.emit: model, $data;
    CATCH {
        default {
            self.emit: model, $data, :error($_);
            proceed
        }
    }
    True
}

#| Applies phasers
method apply-row-phasers($obj, Mu:U $phase) {
    for $obj.^methods.grep($phase) -> $meth {
        $obj.$meth();
    }
}

multi method save(Red::Driver :$with!, |c) {
    my $*RED-DB = $with;
    self.save: |c
}

multi method save(Str :$with!, |c) {
    my $*RED-DB = %GLOBAL::RED-DEFULT-DRIVERS{$with};
    self.save: |c
}

#| Saves that object on database (create a new row)
multi method save($obj, Bool :$insert! where * == True, Bool :$from-create, :$with where not .defined) {
    self.apply-row-phasers($obj, BeforeCreate) unless $from-create;
    my $ast = Red::AST::Insert.new: $obj;
    my $ret := get-RED-DB.execute: $ast;
    $obj.^saved-on-db;
    $obj.^populate-ids;
    self.apply-row-phasers($obj, AfterCreate) unless $from-create;
    self.emit: $obj, $ast;
    CATCH {
        default {
            self.emit: $obj, $ast, :error($_);
            proceed
        }
    }
    $obj.^clean-up;
    $ret
}

#| Saves that object on database (update the row)
multi method save($obj, Bool :$update! where * == True, :$with where not .defined) {
    self.apply-row-phasers($obj, BeforeUpdate);
    my $ast = Red::AST::Update.new: $obj;
    my $ret := get-RED-DB.execute: $ast;
    $obj.^saved-on-db;
    $obj.^populate-ids;
    self.apply-row-phasers($obj, AfterUpdate);
    self.emit: $obj, $ast;
    CATCH {
        default {
            self.emit: $obj, $ast, :error($_);
            proceed
        }
    }
    $obj.^clean-up;
    $ret
}

#| Generic save, calls C<.^save: :insert> if C<.^is-on-db> or C<.^save: :update> otherwise
multi method save($obj, :$with where not .defined) {
    do if $obj.^is-on-db {
        self.save: $obj, :update
    } else {
        self.save: $obj, :insert
    }
}

multi method create(Red::Driver :$with!, |c) {
    my $*RED-DB = $with;
    self.create: |c
}

multi method create(Str :$with!, |c) {
    self.create: :with(%GLOBAL::RED-DEFULT-DRIVERS{$with}), |c
}

#| Creates a new object and saves it on DB
#| It accepts a list os pairs (the same as C<.new>)
#| And Lists and/or Hashes for relationships
multi method create(\model, *%orig-pars, :$with where not .defined) is rw {
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
        my @ids = model.^id>>.column>>.attr-name;
        my $filter = model.^id-filter: |do if $data.defined and not $data.elems {
            $*RED-DB.execute(Red::AST::LastInsertedRow.new: model).row{|@ids}:kv
        } else {
            $data{|@ids}:kv
        }.Hash if @ids;

        for %positionals.kv -> $name, @val {
            FIRST my $no = model.^find($filter);
            $no."$name"().create: |$_ for @val
        }
        self.apply-row-phasers($obj, AfterCreate);
        return-rw Proxy.new:
                STORE => -> | {
                    die X::Assignment::RO.new(value => $obj)
                },
                FETCH => {
                    $ //= do {
                        my $obj;
                        my $*RED-DB = $RED-DB;
                        with $filter {
                            $obj = model.^find: $_
                        } else {
                            $obj = model.new($data.elems ?? |$data !! %orig-pars);
                            $obj.^saved-on-db;
                            $obj.^clean-up;
                            $obj.^populate-ids;
                        }
                        $obj
                    }
                }
    }
}

multi method delete(Red::Driver :$with!, |c) {
    my $*RED-DB = $with;
    self.delete: |c
}

multi method delete(Str :$with!, |c) {
    my $*RED-DB = %GLOBAL::RED-DEFULT-DRIVERS{$with};
    self.delete: |c
}

#| Deletes row from database
multi method delete(\model, :$with where not .defined) {
    my $origin = model.clone;
    self.apply-row-phasers(model, BeforeDelete);
    my $ast = Red::AST::Delete.new: model;
    get-RED-DB.execute: $ast;
    self.emit: model, $ast, :$origin;
    CATCH {
        default {
            self.emit: model, $ast, :$origin, :error($_);
            proceed
        }
    }
    self.apply-row-phasers(model, AfterDelete);
}

multi method load(Red::Driver :$with!, |c) {
    my $*RED-DB = $with;
    self.load: |c
}

multi method load(Str :$with!, |c) {
    my $*RED-DB = %GLOBAL::RED-DEFULT-DRIVERS{$with};
    self.load: |c
}

#| Loads object from the DB
multi method load(Red::Model:U \model, |ids) {
    my $filter = model.^id-filter: |ids;
    model.^rs.grep({ $filter }).head
}

#| Creates a new object setting ids with this values
multi method new-with-id(Red::Model:U \model, %ids, :$with where not .defined) {
    model.new: |model.^id-map: |%ids;
}

multi method new-with-id(Red::Driver :$with!, |c) {
    my $*RED-DB = $with;
    self.new-with-id: |c
}

multi method new-with-id(Str :$with!, |c) {
    my $*RED-DB = %GLOBAL::RED-DEFULT-DRIVERS{$with};
    self.new-with-id: |c
}

#| Creates a new object setting the id
multi method new-with-id(Red::Model:U \model, |ids) {
    model.new: |model.^id-map: |ids;
}

multi method search(Red::Driver :$with!, |c) {
    my $*RED-DB = $with;
    self.search: |c
}

multi method search(Str :$with!, |c) {
    my $*RED-DB = %GLOBAL::RED-DEFULT-DRIVERS{$with};
    self.search: |c
}

#| Receives a `Block` of code and returns a `ResultSeq` using the `Block`'s return as filter
multi method search(Red::Model:U \model, &filter, :$with where not .defined) {
    model.^rs.grep: &filter
}

#| Receives a `AST` of code and returns a `ResultSeq` using that `AST` as filter
multi method search(Red::Model:U \model, Red::AST $filter, :$with where not .defined) {
    samewith model, { $filter }
}

#| Receives a hash of `AST`s of code and returns a `ResultSeq` using that `AST`s as filter
multi method search(Red::Model:U \model, *%filter, :$with where not .defined) {
    samewith
        model,
        %filter.kv
            .map(-> $k, $value { Red::AST::Eq.new: model."$k"(), Red::AST::Value.new: :$value })
            .reduce: { Red::AST::AND.new: $^a, $^b }
}

multi method find(Red::Driver :$with!, |c) {
    my $*RED-DB = $with;
    self.find: |c
}

multi method find(Str :$with!, |c) {
    my $*RED-DB = %GLOBAL::RED-DEFULT-DRIVERS{$with};
    self.find: |c
}

#| Finds a specific row
multi method find(|c) { self.search(|c).head }

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
