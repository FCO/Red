use Red;

unit model Attend is rw;

# relationship
has UInt $!person-id is referencing{:column<key>, :model<Person>};
has      $.person    is relationship{:column<key>, :model<Person>};

# data:
has UInt $.year      is column;
has Str  $.notes     is column{:nullable};
