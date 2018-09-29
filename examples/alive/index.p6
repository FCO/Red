use Red;
use Schema;

my $*RED-DB = database "SQLite";

.^create-table for Chat, Log, Person;

my $chat = Chat.^create: :id<123>;

$chat.give-birth: "abc", "FCO";
$chat.give-birth: "abd", "AJA";
$chat.give-birth: "abe", "FACO";
$chat.give-birth: "abf", "SACO";

say $chat.alive.map: *.nick;

$chat.kill: "FCO";

say $chat.alive.map: *.nick;

$chat.resurrect: "FCO";

say $chat.alive.map: *.nick;
