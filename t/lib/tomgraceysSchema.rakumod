use Red;

model User {
        has Int $!id is serial;
        has Str $.username is column is rw;
        has Str $.password is column{ :nullable } is rw;
        has @.vmails is relationship(*.user_id, :model<Vmail>);
}

model Vmail {
        has Int $!id is serial;
        has Int $!user_id is referencing(*.id, :model<User>);
        has Str $.name is column;
        has $.user is relationship(*.id, :model<User>);
}
