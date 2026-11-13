use Red;
use Configuration ();
use Red::DB;
use Red::Do;
use Red::Runtime::Configuration;
use Red::Migration::Configuration;
use Red::Migration::Environment;
use X::Red::Exceptions;
use MONKEY-SEE-NO-EVAL;

unit module Red::Fixture;

class GLOBAL::X::Red::Fixture is X::Red {
    has Str $.reason is required;
    has Exception $.cause;
    method message { $!reason ~ ($!cause.defined ?? ": {$!cause.message}" !! '') }
}

sub fixture-error(Str $reason) {
    X::Red::Fixture.new(:$reason).throw
}

# Serialize only known value types; arbitrary objects' .raku methods need not round-trip.
sub literal($value --> Str) {
    return 'Nil' unless $value.defined;
    given $value {
        when Bool | Int | Rat | FatRat | Num | Str { .raku }
        when Blob { 'Buf.new(' ~ .list.join(',') ~ ')' }
        when Positional { .elems ?? '[' ~ .map({ literal($_) }).join(',') ~ ',]' !! '[]' }
        when Associative {
            fixture-error('Fixture map keys must be strings') unless .keys.all ~~ Str;
            '%(' ~ .keys.sort.map({ .raku ~ ' => ' ~ literal($value{$_}) }).join(',') ~ ')'
        }
        default { fixture-error("Unsupported fixture value type: {$value.^name}") }
    }
}

sub value-key($value --> Str) {
    $value ~~ Numeric ?? 'number:' ~ $value.Str !! literal($value)
}

sub export-source($*RED-DB, @models --> Str) {
    my @records;
    my %index;
    for @models -> $model {
        my @columns = $model.^columns.grep({ !.column.computation.defined });
        next unless @columns;
        my $statement = $*RED-DB.execute('SELECT '
            ~ @columns.map({ $*RED-DB.table-name-wrapper(.column.name) }).join(', ')
            ~ ' FROM ' ~ $*RED-DB.table-name-wrapper($model.^table));
        loop {
            my Mu $raw = $statement.row;
            last unless $raw ~~ Associative && $raw.elems;
            my %raw = $raw;
            my %row;
            for @columns -> $attribute {
                my $column = $attribute.column;
                # Read stored values directly: hydration can replace SQL NULL with defaults.
                my $value = %raw{$column.name};
                $value = $*RED-DB.deflate($value) if $value.defined;
                literal($value); # Validate before publishing any output.
                %row{$column.attr-name} = $value.defined ?? $value !! Nil;
                CATCH {
                    default {
                        X::Red::Fixture.new(:reason(
                            "Cannot export {$model.^name}.{$attribute.column.attr-name}"),
                            :cause($_)).throw;
                    }
                }
            }
            my $id = @records.elems;
            @records.push: %(model => $model, values => %row, dependencies => []);
            for %row.kv -> $name, $value {
                %index{$model.^name}{$name}{value-key($value)}.push($id) if $value.defined;
            }
        }
    }
    for @records.kv -> $id, %record {
        for %record<model>.^columns -> $attribute {
            my $column = $attribute.column;
            next unless $column.references.defined;
            my $value = %record<values>{$column.attr-name};
            next unless $value.defined;
            my $reference = $column.ref;
            my $target-index = %index{$reference.class.^name}{$reference.attr-name} // {};
            my @targets = |($target-index{value-key($value)} // []);
            fixture-error("Missing referenced row for {%record<model>.^name}.{$column.attr-name}")
                unless @targets;
            %record<dependencies>.append(@targets.grep(* != $id));
        }
    }
    my @source = 'use Red;', 'use Red::Runtime::Configuration;',
        'my %models = runtime-settings().model-types.map({ .^name => $_ }).Hash;';
    my @pending = ^@records.elems;
    my %done;
    while @pending {
        my @ready = @pending.grep(-> $id {
            !@records[$id]<dependencies>.grep({ !(%done{$_}:exists) }).elems
        });
        fixture-error('Cyclic references prevent fixture insertion') unless @ready;
        for @ready -> $id {
            my %record = @records[$id];
            @source.push: '%models{' ~ %record<model>.^name.raku ~ '}.'
                ~ '^populate(:deflated, :rows([' ~ literal(%record<values>) ~ ',]));';
            %done{$id} = True;
        }
        @pending = @pending.grep({ !(%done{$_}:exists) });
    }
    @source.push('True;');
    @source.join("\n") ~ "\n"
}

sub advance-sequences($db, @models) {
    $db.advance-sequences(@models);
}

sub apply-file($*RED-DB, Str $path, @models) {
    red-do :transaction, {
        EVALFILE($path);
        advance-sequences(get-RED-DB(), @models);
        True
    };
}

sub save-file($*RED-DB, IO::Path $target, @models, Bool :$force) {
    my $source;
    red-do :transaction, { $source = export-source(get-RED-DB(), @models); True };
    $target.parent.mkdir(:parents) unless $target.parent.d;
    my $stage = $target.parent.add(".{$target.basename}-{$*PID}-{100000000.rand.Int}.tmp");
    LEAVE $stage.unlink if $stage.defined && $stage.e;
    my $handle = $stage.open(:w, :createonly);
    $handle.print($source);
    $handle.close;
    if $force {
        $stage.rename($target);
    } else {
        # A hard link publishes atomically without replacing a concurrent writer's fixture.
        link($stage, $target) or fixture-error("Cannot publish fixture: $target");
    }
}

sub fixture-command(Str $command, Str $name = '', Str :$config = 'red.rakuconf',
                    Bool :$force = False) is export {
    CATCH {
        when X::Red::Fixture { .rethrow }
        default {
            X::Red::Fixture.new(:reason("Fixture $command '$name' failed"), :cause($_)).throw
        }
    }
    fixture-error("Unknown fixture command: $command") unless $command eq any(<save list apply>);
    my $file = $config.IO.absolute.IO;
    fixture-error("Configuration not found: $file") unless $file.f;
    my $settings = Red::Migration::Configuration.load($file);
    my $directory = $settings.fixtures-directory;
    $directory = $file.parent.add($directory.Str) unless $directory.is-absolute;
    if $command eq 'list' {
        .say for ($directory.d ?? $directory.dir.grep({ .f && .extension eq 'raku'
            && .basename ~~ /^ <[A..Za..z0..9_\-]>+ '.raku' $/ })
            .map(*.basename.subst(/'.raku' $/, '')).sort !! ());
        return;
    }
    fixture-error('Invalid fixture name') unless $name ~~ /^ <[A..Za..z0..9_\-]>+ $/;
    my $target = $directory.add("$name.raku");
    fixture-error("Fixture not found: $name") if $command eq 'apply' && !$target.f;
    fixture-error("Fixture already exists: $name; use --force")
        if $command eq 'save' && $target.e && !$force;
    {
        # Scope Configuration's reader so callers retain their settings.
        my $*CONFIG-OBJECT = Configuration.new(:root(Red::Migration::Configuration), :file($file));
        set-config -> { $settings };
        my @models = $settings.model-types;
        # Match other CLI commands inside migration test environments without touching the normal DB.
        my $driver = %*ENV<RED_MIGRATION_TEST> ?? test-database() !! get-RED-DB();
        if $command eq 'apply' {
            apply-file($driver, $target.absolute.Str, @models);
        } else {
            save-file($driver, $target, @models, :$force);
        }
    }
}
