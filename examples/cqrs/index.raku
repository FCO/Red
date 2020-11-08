use lib <lib ../../lib>;
use Red;

model Event { ... }

model Ticket {
    has Str $.id            is id;
    has Str $.title         is column;
    has Str $.status        is column is rw;

    multi method apply-event(@events) {
        my $ticket = self;
        $ticket .= apply-event: $_ for @events;
        $ticket
    }

    multi method apply-event(::?CLASS:U: Event $_ where .event-type eq "new-ticket") {
        ::?CLASS.new: :id(.ticket-id), :title(.title), :status(.status)
    }

    multi method apply-event(::?CLASS:D: Event $_ where .event-type eq "change-status") {
        self.status = .status;
        self
    }
}

model Event is nullable {
    has UInt        $.id            is serial;
    has DateTime    $.created       is column{:!nullable} .= now;
    has Str         $.ticket-id     is column;
    has Str         $.event-type    is column{:!nullable};
    has Str         $.name          is column;
    has Str         $.title         is column;
    has Str         $.status        is column = "new";

    method event-supplier {
        $ //= Supplier.new
    }

    method ^create(|c) {
        my \obj = callsame;
        Event.event-supplier.emit: obj;
        obj
    }

    method load-events(::?CLASS:U: Str $ticket-id) {
        self.^all.grep({ .ticket-id eq $ticket-id })
    }

    method new-ticket(::?CLASS:U: $ticket-id, $title) {
        self.^create:
            :$ticket-id,
            :event-type<new-ticket>,
            :$title,
    }

    method open(::?CLASS:U: Str $ticket-id) {
        self.^create:
            :$ticket-id,
            :event-type<change-status>,
            :status<opened>,
    }

    method close(::?CLASS:U: Str $ticket-id) {
        self.^create:
            :$ticket-id,
            :event-type<change-status>,
            :status<closed>,
    }
}

my $*RED-DEBUG = True;
my $*RED-DB = database "SQLite";

start react whenever Event.event-supplier.Supply -> $event {
    CATCH { default { .say } }
    with Ticket.^load: $event.ticket-id {
        .apply-event($event).^save
    } else {
        Ticket.apply-event($event).^save: :insert;
    }
}

Event.^create-table;
Ticket.^create-table;

Event.new-ticket: "aaaaa", "test";

Event.open: "aaaaa";

.say for Ticket.^all
