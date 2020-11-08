#use Telegram;
use Red;
use Schema;

class Msg {
    has $!bot;
    has $.chat;
    has $.sender;
    has Str $.text;

    method TWEAK(:$!bot!, :$msg!) {
        $!chat   = $msg.chat;
        $!sender = $msg.sender;
        $!text   = $msg.text;
    }

    method answer(Str() $text, Bool :$prefix = True) {
        say self;
        $!bot.sendMessage: :chat_id($!chat.id), :text(self!encode-msg: "{ "{ $!sender.username }:" if $prefix } $text")
    }

    method !encode-msg($msg) { $msg.subst: /<-alnum>/, *.ord.fmt("%%%02X"), :g }

    method is-cmd(--> Bool()) { $!text.starts-with: "/" }

    method command(--> Str()) {
        die "Not a command" unless self.is-cmd;
        $!text.substr(1).split(" ").head
    }

    method args(--> Str()) {
        die "Not a command" unless self.is-cmd;
        my $index = $!text.index: " ";
        return Str without $index;
        $!text.substr(1 + $index).head
    }
}

my $*RED-DB = database "SQLite", :database<./alive.db>;

.^create-table for Chat, Person, Log;

#my $bot = Telegram::Bot.new: "<the botfather token>";
#$bot.start(interval => 1);

#my $msgTap = $bot.messagesTap;

#react {
#        whenever $msgTap.map(-> $msg { Msg.new: :$bot, :$msg }).grep: *.is-cmd -> $msg {
#            my $nick    = $msg.sender.username;
#            if $msg.command eq "start" {
#                    say "started";
#                    Chat.^create: :id($msg.chat.id);
#                    $msg.answer: "Started";
#            } else {
#                    my $chat = Chat.^find: id => $msg.chat.id;
#
#                    given $msg.command {
#                        when "give-birth" {
#                                say "give-birth";
#                                $chat.give-birth: $msg.sender.id, $nick;
#                                $msg.answer: "$nick was born."
#                        }
#                        when "kill" {
#                                say "kill";
#                                $chat.kill: $msg.args;
#                                $msg.answer: "{ $msg.args } was killed."
#                        }
#                        when "resurrect" {
#                                say "resurrect";
#                                $chat.resurrect: $msg.args;
#                                $msg.answer: "{ $msg.args } is alive again."
#                        }
#                        when "alive" {
#                                say "alive";
#                                for $chat.alive.map: *.nick -> $user {
#                                        $msg.answer: $user, :!prefix
#                                }
#                        }
#                        default {
#                                $msg.answer: "command '{ $_ }' not recognized"
#                        }
#                    }
#
#                }
#        }
#        whenever signal(SIGINT) {
#                $bot.stop;
#                exit;
#        }
#}
