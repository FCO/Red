use v6;
use Red::GlobalEvents;

=head2 Red::Driver::Events

#| Backend hooks for cross-process (multi-node) model events. Drivers that do not
#| support notifications keep Red's original in-process event stream.
unit role Red::Driver::Events;

#| Does this backend support global notifications?
method supports-global-events(--> Bool:D) { False }

#| DDL publishing inserts for one model. Each item is a C<name => SQL> pair; the
#| SQL must be idempotent so direct table creation and migrations can share it.
method global-event-triggers(Mu:U --> Array:D) { [] }

#| Install notification DDL for the supplied models.
method install-global-event-triggers(@models) {
    my @marked = @models.grep({ .^global-notifiable }).Array;
    for @marked -> Mu \model {
        unless self.supports-global-events {
            Red::GlobalEvents::warn-unsupported(model, self);
            next
        }
        self.execute(.value) for self.global-event-triggers(model);
    }
    self
}

#| Driver used by the global-event listener. Transaction-scoped drivers can
#| override this to return a stable connection for materializing notifications.
method global-event-listener-driver { self }

#| Start listening and call C<&on-event> with a hash containing C<model> and C<ids>.
#| The returned value is kept as the listener handle.
method listen-global-events(@models, &on-event) { Nil }

#| SQL removing one notification trigger definition (used by migrations).
method migration-drop-global-event-trigger(Str $table, Str $name --> Str:D) { '' }
