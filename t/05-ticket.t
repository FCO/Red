use Test;
use Red;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

model TicketStatus {
    has UInt $.id       is serial;
    has Str  $.name     is column{ :unique };
}

TicketStatus.^create-table;

my $new     = TicketStatus.^create: :name<new>;
my $opened  = TicketStatus.^create: :name<opened>;
my $closed  = TicketStatus.^create: :name<closed>;
my $blocked = TicketStatus.^create: :name<blocked>;
my $paused  = TicketStatus.^create: :name<paused>;

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
    has UInt            $.status-id is referencing( *.id, :model<TicketStatus> );
    has TicketStatus    $.status    is relationship{ .status-id } = $new;
    has UInt            $.author-id is referencing( *.id, :model<Person> );
    has Person          $.author    is relationship{ .author-id }
}

schema(Ticket, Person).create;

my \me = Person.^create: :name<Me>;
isa-ok me, Person;
is me.name, "Me";
is me.id, 1;

my $t1 = me.tickets.create: :title("new ticket 01"), :body("Creating a ticket just to be sure it works");
isa-ok $t1, Ticket;
is $t1.title, "new ticket 01";
is $t1.body, "Creating a ticket just to be sure it works";

my $t2 = me.tickets.create: :title("new ticket 02"), :body("Creating another ticket just to be sure it works");
isa-ok $t2, Ticket;
is $t2.title, "new ticket 02";
is $t2.body, "Creating another ticket just to be sure it works";

my $t3 = me.tickets.create: :title("new ticket 03"), :body("Creating one more ticket just to be sure it works");
isa-ok $t3, Ticket;
is $t3.title, "new ticket 03";
is $t3.body, "Creating one more ticket just to be sure it works";

my $t4 = me.tickets.create: :title("new ticket 04"), :body("Creating the last ticket just to be sure it works");
isa-ok $t4, Ticket;
is $t4.title, "new ticket 04";
is $t4.body, "Creating the last ticket just to be sure it works";

for me.tickets -> $t {
    is $t.status.name, "new"
}

given me.tickets.head {
    .status = $closed;
    .^save;
}

todo "Its repeting the last results";
for me.tickets -> $t {
    is $t.status.name, ["closed", |("new" xx *)].[$++]
}

done-testing
