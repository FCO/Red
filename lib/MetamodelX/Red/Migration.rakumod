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

#| Generate SQL for populating columns during migration
method migration(\model, Red::Model:U :$from!, Str :$target-column!) {
    use Red::AST;
    use Red::AST::Function;
    use Red::AST::Identifier;
    use Red::AST::Value;
    
    # Get the attributes for both models
    my %old-columns = $from.^columns.map: { .name.substr(2) => $_ };
    my %new-columns = model.^columns.map: { .name.substr(2) => $_ };
    
    # Check if target column exists in new model
    unless %new-columns{$target-column} {
        die "Target column '$target-column' not found in {model.^name}";
    }
    
    # Generate transformation SQL/AST for the target column
    return self!generate-population-transformation($target-column, %old-columns, %new-columns);
}

#| Generate population transformation for a specific column
method !generate-population-transformation($target-column, %old-columns, %new-columns) {
    my $new-attr = %new-columns{$target-column};
    
    # Try to match by name first (simple case)
    if %old-columns{$target-column} {
        return Red::AST::Identifier.new($target-column);
    }
    
    # Try common transformation patterns
    given $target-column {
        when 'full_name' | 'full-name' {
            # Try to combine first_name + last_name
            if %old-columns<first_name> && %old-columns<last_name> {
                return Red::AST::Function.new(
                    name => 'CONCAT',
                    args => [
                        Red::AST::Identifier.new('first_name'),
                        Red::AST::Value.new(' '),
                        Red::AST::Identifier.new('last_name')
                    ]
                );
            }
        }
        when 'hashed_password' | 'hashed-password' {
            # Transform plain password to hashed
            if %old-columns<password> || %old-columns<plain_password> {
                my $source-col = %old-columns<password> ?? 'password' !! 'plain_password';
                return Red::AST::Function.new(
                    name => 'CONCAT',
                    args => [
                        Red::AST::Value.new('hash:'),
                        Red::AST::Identifier.new($source-col)
                    ]
                );
            }
        }
        when 'email_lower' | 'email-lower' {
            # Transform email to lowercase
            if %old-columns<email> {
                return Red::AST::Function.new(
                    name => 'LOWER',
                    args => [Red::AST::Identifier.new('email')]
                );
            }
        }
        when /^is_/ | /^is-/ {
            # Boolean transformation from status fields
            my $base-name = $target-column.subst(/^is[-_]/, '');
            if %old-columns<status> {
                return Red::AST::Function.new(
                    name => 'CASE',
                    args => [
                        Red::AST::Identifier.new('status'),
                        Red::AST::Value.new($base-name),
                        Red::AST::Value.new(True),
                        Red::AST::Value.new(False)
                    ]
                );
            }
        }
    }
    
    # Default transformation - try to find similar column names
    my @candidates = %old-columns.keys.grep(* ~~ /$target-column/);
    if @candidates.elems == 1 {
        return Red::AST::Identifier.new(@candidates[0]);
    }
    
    # Fallback: return NULL for new columns that can't be derived
    return Red::AST::Value.new(Nil);
}

#| Prints the migrations.
method dump-migrations(|) {
    say "{ .key } => { .value.gist }" for @migrations
}
