use lib <lib ../../lib>;
use Red;

model TicketStatus {
    has UInt $.id       is serial;
    has Str  $.name     is column{ :unique };
}

model Ticket { ... }

model Person {
    has UInt    $.id        is serial;
    has Str     $.name      is column{ :!nullable };
    has Ticket  @.tickets   is relationship{ .author-id };
    method opened-tickets { @!tickets.grep: *.status.name eq "opened" }
}

model Ticket is rw {
    has UInt            $.id        is serial;
    has Str             $.title     is column;
    has Str             $.body      is column;
    has UInt            $.status-id is referencing{  TicketStatus.id };
    has TicketStatus    $.status    is relationship{ .status-id }
    has UInt            $.author-id is referencing{  Person.id }
    has Person          $.author    is relationship{ .author-id }

    method TWEAK(|) {
        $!status = TicketStatus.^find: :name<new>
    }
}

my $*RED-DB = database "SQLite";

TicketStatus.^create-table;

my \new     = TicketStatus.^create: :name<new>;
my \opened  = TicketStatus.^create: :name<opened>;
my \closed  = TicketStatus.^create: :name<closed>;
my \blocked = TicketStatus.^create: :name<blocked>;
my \paused  = TicketStatus.^create: :name<paused>;

Ticket.^create-table;
Person.^create-table;

#my $*RED-DEBUG = True;
my \me = Person.^create: :name<Me>;

me.tickets.create: :title("novo ticket 01"), :body("Creating a ticket just to be sure it works");
me.tickets.create: :title("novo ticket 02"), :body("Creating another ticket just to be sure it works");
me.tickets.create: :title("novo ticket 03"), :body("Creating one more ticket just to be sure it works");
me.tickets.create: :title("novo ticket 04"), :body("Creating the last ticket just to be sure it works");

say me.tickets;
say me.tickets.does: Iterable;
say "1: me.tickets.Seq";
say "{ .status.name } - { .title }" for me.tickets.Seq;
say "2: me.tickets";
say "{ .status.name } - { .title }" for me.tickets;
