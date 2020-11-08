use Red;

model Log     {...}
model Person  {...}

model Chat {
    has Str     $.id      is column;
    has Log     @.logs    is relationship( *.chat-id, :model<Log> );
    has Person  @.people  is relationship( *.chat-id, :model<Person> );

    method alive(--> Sequence) {
        @!people.grep: { .is-alive }
    }

    method give-birth(Int $id, Str $nick) {
        my $user = @!people.create: :$id, :$nick;
        @!logs.create(:msg<born>, :impacted-id($id)).print;
        $user
    }

    method kill(Str $nick) {
        my $people = self.alive.first({ .nick eq $nick });
        $people.die;
        @!logs.create(:msg<killed>, :impacted-id($people.id)).print;
    }

    method resurrect(Str $nick) {
        my $people = @!people.first({ .nick eq $nick });
        $people.resurrect;
        @!logs.create(:msg<resurrected>, :impacted-id($people.id)).print;
    }
}

model Log {
    has Str     $.msg           is column;
    has Str     $.chat-id       is referencing(  *.id, :model<Chat>   );
    has Str     $.impacted-id   is referencing(  *.id, :model<Person> );
    has Chat    $.chat          is relationship( *.chat-id    , :model<Chat>   );
    has Person  $.impacted      is relationship( *.impacted-id, :model<Person> );

    method print { note "{ $!impacted.nick } was $!msg" }
}

model Person {
    has Int     $.id        is id;
    has Str     $.nick      is column;
    has Bool    $.is-alive  is column is rw = True;
    has Str     $.chat-id   is referencing( *.id, :model<Chat> );
    has Chat    $.chat      is relationship( *.chat-id, :model<Chat> );

    method die {
        $!is-alive = False;
        self.^save
    }

    method resurrect {
        $!is-alive = True;
        self.^save
    }
}
