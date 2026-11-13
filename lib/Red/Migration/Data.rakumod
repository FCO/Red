use Red;
use Red::AST::Value;
use Red::Migration::Snapshot;
use X::Red::Migration;
use UUID;
=head2 Red::Migration::Data

unit module Red::Migration::Data;

#| Raise a typed migration compilation error instead of falling back to runtime Raku execution.
sub fail(Str $reason) { X::Red::Migration.new(:$reason).throw }

#| Detect block phasers on both older and newer RakuAST implementations.
sub has-phasers($block --> Bool) {
    return so $block.has-any-phasers if $block.^can('has-any-phasers');
    so <ENTER LEAVE KEEP UNDO FIRST NEXT LAST PRE POST QUIT TEMP CLOSE let temp>.first({
        $block.has-phaser($_)
    })
}

# Reject declarations and phasers before asking the Raku frontend to parse them:
# some declarations execute BEGIN-time code even when only requesting an AST.
#| Reject unsupported declarations, phasers and interpolation before frontend parsing can execute
#| compile-time effects. Transformation files accept a restricted SQL-translatable subset of Raku.
sub check-source(Str $source) {
    my $index = 0;
    my $quote = '';
    while $index < $source.chars {
        my $char = $source.substr($index++, 1);
        if $quote.chars {
            if $char eq '\\' { $index++; next }
            fail('String interpolation requires an explicit Red concatenation expression')
                if $quote eq '"' && $char eq any('$', '@', '%', '{');
            $quote = '' if $char eq $quote;
            next;
        }
        if $char eq '#' {
            $index++ while $index < $source.chars && $source.substr($index, 1) ne "\n";
            next;
        }
        if $char eq any("'", '"') { $quote = $char; next }
        if $char ~~ /<[A..Za..z_]>/ {
            my $previous = $index > 1 ?? $source.substr($index - 2, 1) !! '';
            my $word = $char;
            while $index < $source.chars && $source.substr($index, 1) ~~ /<[A..Za..z0..9_]>/ {
                $word ~= $source.substr($index++, 1);
            }
            fail("Unsupported declaration or phase in migration.raku: $word")
                if $previous ne any('.', ':', '$', '@', '%')
                    && $word eq any(<BEGIN CHECK INIT END START ENTER LEAVE KEEP UNDO FIRST NEXT LAST
                    PRE POST CATCH CONTROL use need require EVAL EVALFILE constant macro class
                    model role module grammar subset enum sub method multi proto augment>);
        }
    }
}

#| Identify required additions and nullable-to-required changes on existing tables. Return their
#| historical model, table and column names for draft generation and assignment validation.
sub required-columns($before, $after --> Array) is export {
    my %old = $before.tables.map({ .name => $_ });
    my @columns;
    for $after.tables -> $table {
        next unless %old{$table.name}:exists;
        for $table.columns -> $column {
            my $previous = %old{$table.name}.columns.first(*.name eq $column.name);
            next if $column.nullable || ($previous.defined && !$previous.nullable);
            fail("Constrained column changes require explicit SQL: {$table.name}.{$column.name}")
                if $column.pk || $column.unique || $column.auto-increment || $column.references;
            @columns.push: %(model => $table.model-name, table => $table.name, column => $column.name);
        }
    }
    @columns.Array
}

#| Generate migration.raku placeholders for columns requiring explicit data preparation. Suggested
#| without modifiers preserve existing defined values.
sub data-template($before, $after --> Str) is export {
    my @required = required-columns($before, $after);
    my @blocks = @required.map(*.<model>).unique.sort.map(-> $model {
        "$model.^migration: \{\n" ~ @required.grep(*.<model> eq $model).map({
            '    $_ = ... without .' ~ .<column>.subst('_', '-', :g) ~ ';'
        }).join("\n") ~ "\n};"
    });
    "# Historical models are supplied by the migration compiler.\n"
        ~ "# Blocks run in source order after structural additions and before final constraints.\n\n"
        ~ @blocks.join("\n\n") ~ "\n"
}

#| Build the schema available while data statements run. Keep existing columns and tables, add new
#| storage, and defer required-column constraints and removals until afterward.
sub intermediate-schema($before, $after --> Red::Migration::Snapshot) is export {
    my %new = $after.tables.map({ .name => $_ });
    my @tables = $before.tables.map(-> $old {
        my $target = %new{$old.name};
        if $target.defined {
            my @added = $target.columns.grep(-> $column {
                !$old.columns.first(*.name eq $column.name).defined
            }).map(*.clone(:nullable));
            $old.clone(:columns([|$old.columns, |@added]), :model-name($target.model-name))
        } else { $old }
    });
    @tables.append: $after.tables.grep(-> $table {
        !$before.tables.first(*.name eq $table.name).defined
    });
    Red::Migration::Snapshot.new(:@tables)
}

#| Encode a supported scalar as a dialect-safe SQL literal. Handle NULL, Booleans and finite
#| numbers; use UTF-8 hexadecimal expressions for strings containing backslashes or NUL.
sub sql-value($value, $driver --> Str) {
    return 'NULL' unless $value.defined;
    return $value ?? 'TRUE' !! 'FALSE' if $value ~~ Bool;
    if $value ~~ Numeric {
        fail('Nonfinite migration literals are unsupported') if $value.Num.isNaN || $value.Num.abs == Inf;
        return $value ~~ Rat ?? $value.Num.Str !! $value.Str;
    }
    fail("Unsupported migration literal: {$value.^name}") unless $value ~~ Str;
    if $value.contains('\\') || $value.contains("\0") {
        return $driver.migration-string-literal($value);
    }
    "'{$value.subst("'", "''", :g)}'"
}

#| Preserve a scalar Red expression together with its dialect-safe SQL literal representation.
class Literal is Red::AST::Value {
    has Str $.sql is required;
}
#| Extend an offline backend with literal rendering that never leaves runtime bind parameters.
role LiteralSQL {
    #| Render an already encoded literal without runtime bind parameters, regardless of the
    #| surrounding expression translation context.
    multi method translate(Literal:D $value, $context?) { $value.sql => [] }
}

#| Lower the supported migration-file RakuAST into ordered SQL against historical model proxies.
class Compiler {
    has $.driver is required;
    has Str $.dialect is required;
    has %.models is required;
    has $.schema is required;
    has %!assigned;
    has @!sql;

    #| Collect direct RakuAST children in source order for the migration-specific lowering pass.
    method children($node --> Array) {
        my @children;
        $node.visit-children(-> $child { @children.push($child) });
        @children.Array
    }
    #| Wrap a scalar with its safely encoded SQL representation while retaining its Red expression
    #| type.
    method literal($value) {
        Literal.new(:$value, :sql(sql-value($value, $!driver)))
    }
    #| Recognize supported Boolean conditions, including comparison, definedness and SQL membership
    #| or LIKE expressions.
    method predicate($value --> Bool) {
        so ($value.returns ~~ Bool || $value ~~ Red::AST::Like | Red::AST::In | Red::AST::NotIn)
    }
    #| Normalize a string or RakuAST identifier into the historical name used during declaration
    #| lookup.
    method name($name --> Str) { $name ~~ Str ?? $name !! $name.canonicalize }
    #| Clone an expression tree with safely encoded literal nodes, preserving column references and
    #| expression structure.
    method literals($expression) {
        return $expression if $expression ~~ Literal | Red::Column;
        return self.literal($expression.get-value) if $expression ~~ Red::AST::Value;
        my %changes;
        for $expression.^attributes -> $attribute {
            my $value = $attribute.get_value($expression);
            if $value.DEFINITE && $value ~~ Red::AST {
                %changes{$attribute.name.substr(2)} = self.literals($value);
            } elsif $value ~~ Positional && $value.grep(Red::AST) {
                %changes{$attribute.name.substr(2)} = $value.map({
                    $_ ~~ Red::AST ?? self.literals($_) !! $_
                }).Array;
            }
        }
        %changes ?? $expression.clone(|%changes) !! $expression
    }
    #| Translate a supported Red expression for this dialect and reject any unresolved runtime bind
    #| parameters.
    method sql($expression --> Str) {
        my $result = $!driver.translate(self.literals($expression), 'where');
        fail('Migration SQL cannot retain runtime bind parameters') if $result.value.elems;
        $result.key
    }
    #| Resolve a historical model column by its Raku accessor name. Unknown members fail before SQL
    #| is published.
    method field($model, Str $name) {
        my $attribute = $model.^columns.first(*.name.substr(2) eq $name);
        fail("Unknown historical column: {$model.^name}.$name") unless $attribute.defined;
        $attribute.column
    }
    #| Lower a supported ordinary column method or model accessor. Reject arbitrary method calls
    #| rather than executing application code.
    method method($call, $receiver) {
        fail('Only ordinary column methods are supported in migration expressions')
            unless $call.^name eq 'RakuAST::Call::Method';
        my $name = self.name($call.name);
        my @args = $call.args.args.map({ self.expr($_, $receiver) });
        if $receiver ~~ Red::Model:U {
            fail('Column access cannot have arguments') if @args;
            return self.field($receiver, $name);
        }
        fail("Unsupported migration method: $name")
            unless $name eq any(<defined chars lc uc substr contains starts-with ends-with>);
        # Literal method arguments are ordinary Raku values, such as substr offsets.
        my @values = @args.map({ $_ ~~ Literal ?? .value !! $_ });
        $receiver."$name"(|@values)
    }
    #| Lower a supported RakuAST scalar expression into Red SQL expressions, using the current model
    #| or topicalized column as its topic.
    method expr($node, $topic) {
        given $node.^name {
            when 'RakuAST::Statement::Expression' { return self.expr($node.expression, $topic) }
            when 'RakuAST::IntLiteral' | 'RakuAST::NumLiteral' | 'RakuAST::RatLiteral'
                | 'RakuAST::StrLiteral' {
                return self.literal($node.compile-time-value)
            }
            when 'RakuAST::Term::Enum' {
                return self.literal(True) if self.name($node.name) eq 'True';
                return self.literal(False) if self.name($node.name) eq 'False';
            }
            when 'RakuAST::Type::Simple' {
                return self.literal(Any) if self.name($node.name) eq any(<Nil Any Str Int Num Rat Bool>);
            }
            when 'RakuAST::QuotedString' {
                fail('Only non-interpolated migration strings are supported')
                    unless $node.segments.map(*.^name).all eq 'RakuAST::StrLiteral';
                return self.literal($node.segments.map(*.compile-time-value).join);
            }
            when 'RakuAST::Term::TopicCall' {
                return self.method(self.children($node)[0], $topic);
            }
            when 'RakuAST::ApplyPostfix' {
                return self.method($node.postfix, self.expr($node.operand, $topic));
            }
            when 'RakuAST::Var::Lexical' {
                return $topic if $node.name eq '$_';
            }
            when 'RakuAST::Circumfix::Parentheses' {
                my @parts = $node.semilist.statements;
                fail('Migration expressions require one scalar value') unless @parts.elems == 1;
                return self.expr(@parts[0], $topic);
            }
            when 'RakuAST::ApplyPrefix' {
                my $value = self.expr($node.operand, $topic);
                given $node.prefix.operator {
                    when '+' { return +$value }
                    when '-' { return -$value }
                    when '!' { return $value.not }
                    when '~' { return Red::AST::Concat.new(self.literal(''), $value) }
                }
            }
            when 'RakuAST::ApplyInfix' {
                my $a = self.expr($node.left, $topic);
                my $b = self.expr($node.right, $topic);
                given $node.infix.operator {
                    when '+' { return $a + $b }
                    when '-' { return $a - $b }
                    when '*' { return $a * $b }
                    when '/' { return $a / $b }
                    when '~' { return $a ~ $b }
                    when 'eq' { return $a eq $b }
                    when 'ne' { return $a ne $b }
                    when '==' { return $a == $b }
                    when '!=' { return $a != $b }
                    when '<' { return $a < $b }
                    when '<=' { return $a <= $b }
                    when '>' { return $a > $b }
                    when '>=' { return $a >= $b }
                    when '&&' | 'and' { return Red::AST::AND.new($a, $b) }
                    when '||' | 'or' { return Red::AST::OR.new($a, $b) }
                }
            }
            when 'RakuAST::Term::Name' {
                return self.literal(True) if self.name($node.name) eq 'True';
                return self.literal(False) if self.name($node.name) eq 'False';
                return self.literal(Any) if self.name($node.name) eq any(<Nil Any>);
            }
        }
        fail("Unsupported migration expression: {$node.^name}");
    }
    #| Lower migration assignments or explicit populate inserts in source order. Preserve modifier
    #| topic semantics and conditions; conditional blocks are restricted to one assignment to avoid
    #| re-evaluating a mutated predicate.
    method statements($block, $model, Str $kind, $topic = $model, $condition = Any) {
        fail('Migration blocks cannot declare parameters or phasers')
            if has-phasers($block) || $block.has-placeholder-parameters || $block.signature.DEFINITE;
        for $block.body.statement-list.statements -> $statement {
            if $statement.^name eq any(<RakuAST::Statement::If RakuAST::Statement::Unless
                    RakuAST::Statement::With RakuAST::Statement::Without>) {
                my $name = $statement.^name.split('::').tail;
                fail('Conditional populate blocks require explicit SQL') unless $kind eq 'migration';
                fail('Conditional else branches require explicit SQL')
                    if $statement.^can('else') && $statement.else.DEFINITE;
                my $body = $name eq 'If' ?? $statement.then !! $statement.body;
                fail('Conditional blocks require one assignment to preserve predicate evaluation')
                    unless $body.body.statement-list.statements.elems == 1;
                my $value = self.expr($statement.condition, $topic);
                my $test = $name eq any(<With Without>) ?? $value.defined !! $value;
                fail('Migration conditions require a Boolean comparison or defined check')
                    unless self.predicate($test);
                $test = $test.not if $name eq any(<Unless Without>);
                my $predicate = $condition.DEFINITE ?? Red::AST::AND.new($condition, $test) !! $test;
                self.statements($body, $model, $kind,
                    $name eq any(<With Without>) ?? $value !! $topic, $predicate);
                next;
            }
            fail("Unsupported migration statement: {$statement.^name}")
                unless $statement.^name eq 'RakuAST::Statement::Expression'
                    && !$statement.loop-modifier.DEFINITE;
            my $subject = $topic;
            my $predicate = $condition;
            if $statement.condition-modifier.DEFINITE {
                my $modifier = $statement.condition-modifier;
                my $name = $modifier.^name.split('::').tail;
                fail("Unsupported migration modifier: $name") unless $name eq any(<If Unless With Without>);
                my $value = self.expr(self.children($modifier)[0], $topic);
                my $test = $name eq any(<With Without>) ?? $value.defined !! $value;
                fail('Migration conditions require a Boolean comparison or defined check')
                    unless self.predicate($test);
                $subject = $value if $name eq any(<With Without>);
                $test = $test.not if $name eq any(<Unless Without>);
                $predicate = $condition.DEFINITE ?? Red::AST::AND.new($condition, $test) !! $test;
            }
            my $expression = $statement.expression;
            if $kind eq 'populate' {
                fail('Conditional populate blocks require explicit SQL') if $predicate.DEFINITE;
                fail('Populate supports ordinary .^create calls')
                    unless $expression.^name eq 'RakuAST::Term::TopicCall';
                my $call = self.children($expression)[0];
                fail('Populate supports ordinary .^create calls')
                    unless $call.^name eq 'RakuAST::Call::MetaMethod' && self.name($call.name) eq 'create';
                my %values;
                for $call.args.args -> $arg {
                    fail('Populate requires explicit named column values')
                        unless $arg.^name eq 'RakuAST::ColonPair::Value';
                    my $name = $arg.key.subst('-', '_', :g);
                    fail("Duplicate populate column: $name") if %values{$name}:exists;
                    self.field($model, $arg.key);
                    %values{$name} = self.expr($arg.value, $subject);
                    fail('Populate values cannot read another row')
                        if %values{$name}.transpose-grep(* ~~ Red::Column);
                }
                fail('Populate requires at least one explicit column') unless %values;
                my @columns = %values.keys.sort;
                @!sql.push: 'INSERT INTO ' ~ $!driver.table-name-wrapper($model.^table)
                    ~ ' (' ~ @columns.map({ $!driver.table-name-wrapper($_) }).join(', ') ~ ') VALUES ('
                    ~ @columns.map({ self.sql(%values{$_}) }).join(', ') ~ ')';
            } else {
                fail('Migration blocks support assignments to columns')
                    unless $expression.^name eq 'RakuAST::ApplyInfix'
                        && $expression.infix.^name eq 'RakuAST::Assignment';
                my $target = self.expr($expression.left, $subject);
                fail('Migration assignment must target a column of its model')
                    unless $target ~~ Red::Column && $target.model === $model;
                my $value = self.expr($expression.right, $subject);
                %!assigned{$model.^table ~ '.' ~ $target.name} = True;
                my $sql = 'UPDATE ' ~ $!driver.table-name-wrapper($model.^table)
                    ~ ' SET ' ~ $!driver.table-name-wrapper($target.name) ~ ' = ' ~ self.sql($value);
                $sql ~= ' WHERE ' ~ self.sql($predicate) if $predicate.DEFINITE;
                @!sql.push($sql);
            }
        }
    }
    #| Compile ordered Model.^migration and Model.^populate declarations into SQL statements and a
    #| set of assigned columns. Reject unknown historical models and unsupported declaration shapes.
    method compile($ast --> Hash) {
        for $ast.statements -> $statement {
            my $expression = $statement.expression;
            fail('Only Model.^migration and Model.^populate declarations are supported')
                unless $expression.^name eq 'RakuAST::ApplyPostfix'
                    && $expression.postfix.^name eq 'RakuAST::Call::MetaMethod';
            my $name = self.name($expression.operand.name);
            my $model = %!models{$name};
            fail("Unknown historical model: $name") unless $model ~~ Red::Model:U;
            my $kind = self.name($expression.postfix.name);
            fail("Unsupported migration declaration: $kind") unless $kind eq any(<migration populate>);
            my @args = $expression.postfix.args.args;
            fail('Migration declarations require one block')
                unless @args.elems == 1 && @args[0].^name eq 'RakuAST::Block';
            self.statements(@args[0], $model, $kind);
        }
        %(sql => @!sql.Array, assigned => %!assigned.Hash)
    }
}

#| Compile migration.raku against synthetic models reconstructed from the previous and target
#| snapshots. Return ordered SQL and assigned columns without connecting to a target database or
#| invoking application populate methods.
sub compile-data($before, $after, Str $source, $backend, Str $dialect --> Hash) is export {
    use MONKEY-SEE-NO-EVAL;
    CATCH {
        when X::Red::Migration { .rethrow }
        default { fail("Cannot compile migration.raku: {.message}") }
    }
    fail('Complete the placeholders in migration.raku before preparing') if $source.contains('= ...');
    check-source($source);
    my $middle = intermediate-schema($before, $after);
    my @tables = $middle.tables;
    my %names = @tables.map({ .model-name => $_ });
    my @roots = %names.keys.grep(*.contains('::')).map(*.split('::').head).unique
        .grep({ !(%names{$_}:exists) }).map({ "my package $_ \{ }" });
    my @models = @tables.sort(*.model-name.split('::').elems).map(-> $table {
        fail("Unsupported historical model name: {$table.model-name}")
            unless $table.model-name ~~ /^ <[A..Za..z_]> <[A..Za..z0..9_:]>* $/;
        "model {$table.model-name} is table<{$table.name}> \{\n"
            ~ $table.columns.map({
                fail("Unsupported historical Raku type: {.raku-type}")
                    unless .raku-type ~~ /^ <[A..Za..z_]> <[A..Za..z0..9_:]>* $/;
                '    has ' ~ .raku-type ~ ' $.' ~ .name.subst('_', '-', :g) ~ ' is column{ :nullable };'
            }).join("\n") ~ "\n}"
    });
    my $namespace = 'RedMigrationData' ~ UUID.new.Str.subst('-', '', :g);
    my $program = "do \{ module $namespace \{ use Red;\n" ~ @roots.join("\n") ~ "\n"
        ~ @models.join("\n") ~ '\nour sub captured { ['.subst('\\n', "\n")
        ~ '%(' ~ @tables.map({ .model-name.raku ~ ' => ' ~ .model-name }).join(', ')
        ~ '), ' ~ $source.raku ~ '.AST] } }; ' ~ $namespace ~ '::captured() }';
    my $driver = $backend.^can('backend') ?? $backend.backend.CREATE !! $backend;
    my $*RED-DB = $driver;
    my $*RED-FALLBACK = False;
    my $result = EVAL $program;
    my %compiled = Compiler.new(:driver($driver but LiteralSQL), :$dialect,
        :models($result[0]), :schema($middle)).compile($result[1]);
    for required-columns($before, $after) -> %column {
        fail("Missing migration assignment: {%column<table>}.{%column<column>}")
            unless %compiled<assigned>{%column<table> ~ '.' ~ %column<column>}:exists;
    }
    %compiled
}
