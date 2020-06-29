unit class Red::Cli;
use Red::Database;
use Red::Do;
use Red::Schema;
use Red::Utils;
use Red::AST::CreateColumn;
use Red::AST::ChangeColumn;
use Red::AST::DropColumn;


#| Lists tables from database schema
multi list-tables(
        Str  :$driver!,
        *%pars
) is export {
    my $schema-reader = $*RED-DB.schema-reader;

    $schema-reader.tables-names.do-it
}

sub gen-stub(:@includes, :@models, :$driver, :%pars) {
    my @stub;
    @stub.push: 'use Red:api<2>;';
    for @includes.unique {
        @stub.push: "use $_;"
    }
    @stub.push: "\nred-defaults \"{ $driver }\", { %pars.map(*.perl) };";
    @stub.push: "";
    for @models {
        @stub.push: ".say for { $_ }.^all;"
    }
    @stub
}

#| Generates models' code from database schema
multi gen-stub-code(
        Str  :$schema-class,
        Str  :$driver!,
        *%pars
) is export {
    my $schema-reader = $*RED-DB.schema-reader;

    my @includes;
    my @models;
    for $schema-reader.tables-names -> $table-name {
        my $model-name = snake-to-camel-case $table-name;
        @models.push: $model-name;
        with $schema-class {
            @includes.push: $schema-class;
        } else {
            @includes.push: $model-name;
        }
    }

    gen-stub(:@includes, :@models, :$driver, :%pars).join: "\n"
}


        #| Generates models' code from database schema
multi migration-plan(
        Str :$model!,
        Str :$require = $model,
        Str :$driver!,
        *%pars
) is export {
    my %steps;
    require ::($require);
    for $*RED-DB.diff-to-ast: ::($model).^diff-from-db -> @data {
        say "Step ", ++$, ":";
        #say @data.join("\n").indent: 4
        #        $*RED-DB.translate($_).key.indent(4).say for Red::AST::ChangeColumn.optimize: @data
        $*RED-DB.translate($_).key.indent(4).say for @data
    }
}

#| Generates models' code from database schema
multi generate-code(
        Str  :$path!    where { not .defined or .IO.d or $_ eq "-" or fail "Path $_ does not exist." },
        Str  :$from-sql where { not .defined or .IO.f or $_ eq "-" or fail "SQL $_ do not exist." },
        Str  :$schema-class,
        Bool :$print-stub       = False,
        Bool :$no-relationships = False,
        #Bool :$stub-only,
        Str  :$driver!,
        *%pars
) is export {
    my $schema-reader = $*RED-DB.schema-reader;

    my $schema = do if $path eq "-" {
        $*OUT
    } else {
        $path.IO.add("$_.pm6").open: :!bin, :w with $schema-class
    }

    my $sql = $from-sql eq "-" ?? $*IN !! .IO.open with $from-sql;

    my Bool $no-use = False;
    my @includes;
    my @models;
    for |(
            $sql
                    ?? $sql.slurp
                    !! $schema-reader.tables-names
            ) -> $name-or-sql {
        for |(
                $name-or-sql.contains(" ")
                        ?? $schema-reader.table-definition-from-create-table($name-or-sql)
                        !! $schema-reader.table-definition($name-or-sql)
                ) -> $table-definition {
            my $table-name = $table-definition.name;
            my $model-name = $table-definition.model-name;
            @models.push: $model-name;
            my $fh = do with $schema {
                @includes.push: $schema-class if $schema-class;
                $_
            } else {
                @includes.push: $model-name;
                $path.IO.add("{ $model-name }.pm6").open: :!bin, :w
            }
            $fh.say: "use Red;\n" unless $no-use;
            $fh.say: "#| Table: $table-name";
            $fh.say: $table-definition.to-code:
                    :$no-relationships,
                    |(:$schema-class with $schema-class)
            ;
            with $schema {
                $no-use++ if $schema-class
            } else {
                $fh.close unless $path eq "-";
            }
        }
    }
    $schema.close if $schema.defined and $path ne "-";
    gen-stub :@includes, :@models, :$driver, :%pars if $print-stub
}

#| Prepare database
multi prepare-database(
        Bool :$populate,
        Str  :$models!,
        Str  :$driver!,
        *%pars
) is export {
    my @m = schema($models.split: ",").create.models.values;
    @m.map: { .^populate } if $populate
}