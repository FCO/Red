use Red::AST;
use Red::AST::Insert;
use Red::AST::Value;
use Red::Class;
use Red::Event;
use Red::Model;
use Red::GlobalEvents;

=head2 Red::ResultSeq::Supply

#| Shared "live" supplies for ResultSeq queries.
unit module Red::ResultSeq::Supply;

my %LIVE-SUPPLIES;
my $LOCK = Lock.new;

#| Complete source identity used only at the snapshot/live boundary.
sub supply-identity($value) is export {
    return Str unless $value ~~ Red::Model;
    my @ids = $value.^id-values;
    return Str unless @ids && @ids.all.defined;
    ($value.^orig.WHICH.Str, |@ids.map(*.raku)).raku
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
    return $event.model if $event.model.defined || $event.global;
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

#| Materializes raw insert events; query operations remain private to each tap.
sub build-live(\rs, $driver --> Supply) {
    my \model = source-model(rs);

    my $source = Red::Class.instance.events
        .grep(-> Red::Event $event {
            !$event.error.defined
                && ($event.data ~~ Red::AST::Insert || $event.global)
                && do {
                    my \insert-model = event-model($event);
                    (insert-model === model || insert-model === model.^orig)
                        && $event.db.connection-id eq $driver.connection-id
                }
        })
        .map(-> Red::Event $event {
            my $lock = Lock.new;
            my Bool $resolved = False;
            my $value;
            -> {
                $lock.protect: {
                    unless $resolved {
                        $value = instance-from-event($event);
                        $resolved = True;
                    }
                    $value
                }
            }
        }).share;

    # share subscribes eagerly; defer database access until an actual tap asks
    # for the value. All taps of this event reuse the same materialized row.
    $source.map(-> &resolve { resolve() }).grep(*.defined)
}

#| Returns the raw insert Supply shared by source model and driver.
sub live-supply-for(\rs, Red::AST $ast, $driver --> Supply) is export {
    my $key = $driver.connection-id ~ '|' ~ source-model(rs).WHICH.Str;

    my \model = source-model(rs);
    Red::GlobalEvents::ensure-global-listener($driver, [model])
        if model.^global-notifiable && $driver.defined;

    $LOCK.protect: {
        %LIVE-SUPPLIES{$key} //= build-live(rs, $driver)
    }
}

# Internal boundary marker; never exposed to a caller or a query callback.
class SnapshotEnd is export { }

sub apply-supply-operation(Supply $input, %operation --> Supply) is export {
    given %operation<kind> {
        when 'grep' {
            return $input.grep(-> $value {
                $value ~~ SnapshotEnd || %operation<callback>($value)
            });
        }
        when 'map' {
            return $input.map(-> $value {
                $value ~~ SnapshotEnd ?? $value !! %operation<callback>($value)
            });
        }
        when 'head' | 'skip' {
            return supply {
                my $seen = 0;
                if %operation<kind> eq 'head' && %operation<count> == 0 {
                    done;
                } else {
                    whenever $input -> $value {
                        if $value ~~ SnapshotEnd {
                            emit $value;
                        } elsif %operation<kind> eq 'skip' {
                            emit $value if $seen++ >= %operation<count>;
                        } else {
                            emit $value;
                            done if ++$seen >= %operation<count>;
                        }
                    }
                }
            };
        }
        when 'sort' | 'tail' | 'reverse' {
            return supply {
                my @snapshot;
                my Bool $reading = True;
                sub snapshot-values() {
                    given %operation<kind> {
                        when 'sort' { @snapshot.sort(%operation<callback>) }
                        when 'tail' { @snapshot.tail(%operation<count>) }
                        when 'reverse' { @snapshot.reverse }
                    }
                }
                whenever $input -> $value {
                    LAST {
                        if $reading { emit $_ for snapshot-values() }
                    }
                    if $value ~~ SnapshotEnd {
                        my @values = snapshot-values();
                        @snapshot = ();
                        $reading = False;
                        emit $_ for @values;
                        emit $value;
                    } elsif $reading {
                        @snapshot.push($value);
                    } else {
                        emit $value;
                    }
                }
            };
        }
    }
}
