use lib <lib ../../lib>;
use Red;


my $*RED-DB = database "SQLite";
model TicketStatus {
    has UInt $.id       is serial;
    has Str  $.name     is column{ :unique };
}

TicketStatus.^create-table;

my \new     = TicketStatus.^create: :name<new>;
my \opened  = TicketStatus.^create: :name<opened>;
my \closed  = TicketStatus.^create: :name<closed>;
my \blocked = TicketStatus.^create: :name<blocked>;
my \paused  = TicketStatus.^create: :name<paused>;

model Ticket { ... }

model Person {
    has UInt    $.id        is serial;
    has Str     $.name      is column{ :!nullable };
    has Ticket  @.tickets   is relationship( *.author-id, :model<Ticket> );
    method opened-tickets { @!tickets.grep: *.status.name eq "opened" }
}

model Ticket is rw {
    has UInt            $.id        is serial;
    has Str             $.title     is column;
    has Str             $.body      is column;
    has UInt            $.status-id is referencing( *.id, :model<TicketStatus> );
    has TicketStatus    $.status    is relationship( *.status-id, :model<TicketStatus> ) = new;
    has UInt            $.author-id is referencing( *.id, :model<Person> );
    has Person          $.author    is relationship( *.author-id, :model<Person> );
}

Ticket.^create-table;
Person.^create-table;

#my $*RED-DEBUG = True;
my \me = Person.^create: :name<Me>;

me.tickets.create: :title("new ticket 01"), :body("Creating a ticket just to be sure it works");
me.tickets.create: :title("new ticket 02"), :body("Creating another ticket just to be sure it works");
me.tickets.create: :title("new ticket 03"), :body("Creating one more ticket just to be sure it works");
me.tickets.create: :title("new ticket 04"), :body("Creating the last ticket just to be sure it works");

say "Tickets from { me.name }:";
say "{ .status.name } - { .title }" for me.tickets;

given me.tickets.head {
    say "closing ticket { .title }";
    .status = closed;
    .^save;
}

say "Tickets from { me.name }:";
say "{ .status.name } - { .title }" for me.tickets;
