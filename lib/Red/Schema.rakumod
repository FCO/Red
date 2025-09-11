use Red::Do;
use Red::DB;
use Red::Driver::Pg;
unit class Red::Schema;

proto sub schema(|) { * }

multi sub schema(+@models) is export {
    ::?CLASS.new: @models
}

multi sub schema(*%models) is export {
    ::?CLASS.new: %models
}

has %.models;

multi method new(@models) {
    my %models = @models.map: {
        do if $_ ~~ Str {
            require ::($_);
            $_ => ::($_)
        } else {
            .^name => $_
        }
    }
    self.bless: :%models
}

multi method new(%model-alias) {
    my %models = %model-alias.kv.map: -> $alias, $model {
        do if $model ~~ Str {
            require ::($model);
            $alias => ::($model)
        } else {
            $alias => $model
        }
    }
    self.bless: :%models
}


method FALLBACK(Str $name) {
    $.model($name);
}

method model(Str $name) {
    do if %!models{ $name }:exists {
        %!models{ $name }
    } else {
        fail "Model '$name' not found on schema"
    }
}

# TODO: For tests only, please make it right
method drop {
    for %!models.values {
        my $drop = "DROP TABLE IF EXISTS { get-RED-DB.table-name-wrapper: .^table } { "CASCADE" if get-RED-DB.should-drop-cascade }";
        get-RED-DB.execute($drop);
        #.emit: $drop
    }
    self
}

method create(:$where) {
    red-do (:$where with $where), :transaction, {
        |.create-schema(%!models);
    }
    self
}

#| Updates the database schema to match the model definitions.
#| Compares the current schema definition with the database state
#| and applies necessary changes (add/modify/remove columns, etc.).
#| This method is idempotent and preserves existing data.
method update(:$where) {
    red-do (:$where with $where), :transaction, {
        my $db = get-RED-DB;
        
        # Get differences for each model in the schema and execute changes
        for %!models.values -> $model {
            my @diffs = $model.^diff-from-db;
            if @diffs {
                # Convert differences to AST nodes grouped by execution order
                for $db.diff-to-ast(@diffs) -> @ast-group {
                    for @ast-group -> $ast {
                        my $sql = $db.translate($ast).key;
                        $db.execute($sql) if $sql;
                    }
                }
            }
        }
    }
    self
}
