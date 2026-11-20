use Red::AST;
use Red::AST::Insert;
use Red::AST::Value;
use Red::Class;
use Red::Event;
use Red::Model;
use Red::QueryPlan;

=head2 Red::ResultSeq::Supply

#| Shared "live" supplies for ResultSeq queries.
unit module Red::ResultSeq::Supply;

my %LIVE-SUPPLIES;
my $LOCK = Lock.new;
my atomicint $UNSAFE-COUNTER = 0;

#| Identity used to remove the duplicate emitted at the snapshot/live boundary.
sub supply-identity($value) is export {
    my @ids = $value ~~ Red::Model ?? $value.^id-values.grep(*.defined) !! ();
    @ids ?? @ids.map(*.raku).join('|') !! $value.WHICH.Str
}

#| Returns the original model of a ResultSeq, unwrapping specialised projection models.
sub source-model(\rs) {
    my $model = rs.of;
    my $depth = 0;
    while $model.^can('orig-result-seq') && $depth++ < 20 {
        my $original = $model.orig-result-seq.of;
        last if $original === $model;
        $model = $original;
    }
    $model
}

#| Returns the model associated with an insert event.
sub event-model(Red::Event $event) {
    return $event.origin.WHAT if $event.origin.defined;
    return $event.model if $event.model.defined;
    $event.data.into
}

#| Rebuilds the instance created by an insert event.
sub instance-from-event(Red::Event $event) {
    return $event.materialize-origin.() if $event.materialize-origin.defined;
    return $event.origin if $event.origin.defined;

    my \model = event-model($event);
    return Nil unless model.DEFINITE.not && model.^can('columns');

    my %values = $event.data.values.kv.map: -> $name, $value {
        my $attr = model.^columns.first({ .column.name eq $name });
        ($attr ?? $attr.attr-name !! $name) => (
            $value ~~ Red::AST::Value ?? $value.value !! $value
        )
    };
    my $instance = model.^orig.new: |%values;
    $instance.^saved-on-db;
    $instance
}

#| Builds the pipeline that turns insert events into query results.
sub build-live(\rs, $driver --> Supply) {
    my \model = source-model(rs);

    my $source = Red::Class.instance.events
        .grep(-> Red::Event $event {
            !$event.error.defined
                && $event.data ~~ Red::AST::Insert
                && do {
                    my \insert-model = event-model($event);
                    (insert-model === model || insert-model === model.^orig)
                        && $event.db.connection-id eq $driver.connection-id
                }
        })
        .map(&instance-from-event)
        .grep(*.defined);

    for rs.live-ops.list -> &operation {
        $source = operation($source)
    }

    $source.share
}

#| Returns the live Supply for this AST, binds and driver, creating it if needed.
sub live-supply-for(\rs, Red::AST $ast, $driver --> Supply) is export {
    my %description = try Red::QueryPlan.describe($ast) // {};
    my $base-key = %description<key>.defined
        ?? $driver.connection-id ~ '|' ~ %description<key>
        !! Str;
    my $key = $base-key.defined
        ?? $base-key
        !! 'unsafe|' ~ $ast.WHICH.Str ~ '|' ~ ($UNSAFE-COUNTER⚛++);

    $LOCK.protect: {
        %LIVE-SUPPLIES{$key} //= build-live(rs, $driver)
    }
}
