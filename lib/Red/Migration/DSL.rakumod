use v6;

=head2 Red::Migration::DSL

unit module Red::Migration::DSL;

use MetamodelX::Red::MigrationHOW;
use Red::AST;
use Red::AST::Function;

#| Migration class declaration with user's exact syntax
proto migration(|) is export { * }

#| Create a migration with name as identifier and block  
multi migration($name where { $name ~~ Str || $name.can('Str') }, &block) is export {
    my $migration-name = $name.Str;
    my $migration-class = MetamodelX::Red::MigrationHOW.new_type(
        name => $migration-name,
        description => "Migration: $migration-name"
    );
    
    # Set up migration context
    my $*MIGRATION-CLASS = $migration-class;
    my $*CURRENT-TABLE;
    
    # Execute the migration block
    &block();
    
    # Execute the migration
    $migration-class.HOW.execute-migration();
    
    $migration-class
}

#| Set migration description
sub description(Str $desc) is export {
    $*MIGRATION-CLASS.HOW.set-migration-description($desc);
}

#| Define a table block
sub table(Str $table-name, &block) is export {
    my $*CURRENT-TABLE = $table-name;
    &block();
}

#| Add a new column
proto new-column(|) is export { * }

multi new-column(Str $column-name, &block) is export {
    my %column-spec;
    my $*CURRENT-COLUMN-SPEC = %column-spec;
    &block();
    
    $*MIGRATION-CLASS.HOW.add-operation(
        'new-column', 
        $*CURRENT-TABLE, 
        { $column-name => %column-spec }
    );
}

multi new-column(Str $column-name, %spec) is export {
    $*MIGRATION-CLASS.HOW.add-operation(
        'new-column',
        $*CURRENT-TABLE,
        { $column-name => %spec }
    );
}

# Support colon syntax: new-column name { :type<VARCHAR>, :255size }
multi new-column(Str $column-name, %colon-spec) is export {
    my %spec;
    
    # Convert colon syntax to standard spec
    for %colon-spec.kv -> $key, $value {
        given $key {
            when 'type' { %spec<type> = $value }
            when /^(\d+)size$/ { 
                my $size = +$0;
                if %spec<type> && %spec<type> eq 'VARCHAR' {
                    %spec<type> = "VARCHAR($size)";
                } else {
                    %spec<size> = $size;
                }
            }
            when 'nullable' { %spec<nullable> = $value }
            when 'unique' { %spec<unique> = $value }
            when 'default' { %spec<default> = $value }
            default { %spec{$key} = $value }
        }
    }
    
    $*MIGRATION-CLASS.HOW.add-operation(
        'new-column',
        $*CURRENT-TABLE,
        { $column-name => %spec }
    );
}

#| Column type specification
sub type(Str $type-spec) is export {
    $*CURRENT-COLUMN-SPEC<type> = $type-spec;
}

#| Column size specification 
sub size(Int $size) is export {
    # Modify the type to include size if it's VARCHAR
    if $*CURRENT-COLUMN-SPEC<type> && $*CURRENT-COLUMN-SPEC<type>.starts-with('VARCHAR') {
        $*CURRENT-COLUMN-SPEC<type> = "VARCHAR($size)";
    } else {
        $*CURRENT-COLUMN-SPEC<size> = $size;
    }
}

#| Column nullable specification
sub nullable(Bool $is-nullable = True) is export {
    $*CURRENT-COLUMN-SPEC<nullable> = $is-nullable;
}

#| Column default value
sub default($value = True) is export {
    $*CURRENT-COLUMN-SPEC<default> = $value;
}

#| Column unique constraint
sub unique(Bool $is-unique = True) is export {
    $*CURRENT-COLUMN-SPEC<unique> = $is-unique;
}

#| Primary key specification
sub primary-key(Bool $is-pk = True) is export {
    $*CURRENT-COLUMN-SPEC<primary-key> = $is-pk;
}

#| Add new indexes
proto new-indexes(|) is export { * }

multi new-indexes(*@columns, Bool :$unique = False) is export {
    my %index-spec = columns => @columns, unique => $unique;
    $*MIGRATION-CLASS.HOW.add-operation(
        'new-index',
        $*CURRENT-TABLE,
        %index-spec
    );
}

multi new-indexes(:@columns!, Bool :$unique = False) is export {
    my %index-spec = columns => @columns, unique => $unique;
    $*MIGRATION-CLASS.HOW.add-operation(
        'new-index', 
        $*CURRENT-TABLE,
        %index-spec
    );
}

#| Add a new table
sub new-table(Str $table-name, &block) is export {
    my %table-spec;
    my $*CURRENT-TABLE-SPEC = %table-spec;
    my $*CURRENT-TABLE = $table-name;
    &block();
    
    $*MIGRATION-CLASS.HOW.add-operation(
        'new-table',
        $table-name,
        %table-spec
    );
}

#| Populate columns with data transformation
proto populate(|) is export { * }

multi populate(&transformer) is export {
    # Block-based population for current table
    my %populate-spec = transformer => &transformer;
    $*MIGRATION-CLASS.HOW.add-operation(
        'populate',
        $*CURRENT-TABLE,
        %populate-spec
    );
}

multi populate(Str $column, $transformation) is export {
    # Single column transformation
    my %populate-spec = $column => $transformation;
    $*MIGRATION-CLASS.HOW.add-operation(
        'populate',
        $*CURRENT-TABLE,
        %populate-spec
    );
}

multi populate(%transformations) is export {
    # Hash of column transformations
    $*MIGRATION-CLASS.HOW.add-operation(
        'populate',
        $*CURRENT-TABLE,
        %transformations
    );
}

#| Delete columns
proto delete-columns(|) is export { * }

multi delete-columns(*@columns) is export {
    for @columns -> $column {
        $*MIGRATION-CLASS.HOW.add-operation(
            'delete-column',
            $*CURRENT-TABLE,
            { column => $column }
        );
    }
}

multi delete-columns(@columns) is export {
    for @columns -> $column {
        $*MIGRATION-CLASS.HOW.add-operation(
            'delete-column',
            $*CURRENT-TABLE,
            { column => $column }
        );
    }
}

#| Delete indexes
sub delete-indexes(*@indexes) is export {
    for @indexes -> %index-spec {
        $*MIGRATION-CLASS.HOW.add-operation(
            'delete-index',
            Nil,
            %index-spec
        );
    }
}

#| Delete tables
sub delete-tables(*@tables) is export {
    for @tables -> $table {
        $*MIGRATION-CLASS.HOW.add-operation(
            'delete-table',
            $table,
            %()
        );
    }
}

#| Add foreign key constraint
sub new-foreign-key(Str :$column!, Str :$references-table!, Str :$references-column!) is export {
    my %fk-spec = column => $column, references-table => $references-table, references-column => $references-column;
    $*MIGRATION-CLASS.HOW.add-operation(
        'new-foreign-key',
        $*CURRENT-TABLE,
        %fk-spec
    );
}

#| Add check constraint
sub new-check-constraint(Str :$name!, Str :$expression!) is export {
    my %check-spec = name => $name, expression => $expression;
    $*MIGRATION-CLASS.HOW.add-operation(
        'new-check-constraint',
        $*CURRENT-TABLE,
        %check-spec
    );
}

#| Helper functions for Red::AST integration
sub ast-literal($value) is export {
    Red::AST::Value.new($value)
}

sub ast-column(Str $column) is export {
    Red::AST::Identifier.new($column)
}

sub ast-function(Str $name, *@args) is export {
    Red::AST::Function.new(name => $name, args => @args)
}

sub ast-concat(*@args) is export {
    Red::AST::Function.new(name => 'CONCAT', args => @args)
}