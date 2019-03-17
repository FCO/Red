use Red;

unit model Email is rw;

# relationship
has UInt $!person-id is referencing{:column<id>, :model<Person>};
has      $.person    is relationship{:column<id>, :model<Person>};

# data:
has Str  $.email     is column;
has Str  $.notes     is column{:nullable};
has UInt $.status    is column{:nullable};
