use Red;
unit model Email is rw;
# relationship
has UInt $!person-id is referencing{:column<key>, :model<Person>};
has $.person         is relationship{:column<key>, :model<Person>};

# data:
has Str  $.email     is column;
has Str  $.notes     is column{:nullable};
has UInt $.status    is column{:nullable};

