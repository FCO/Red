use Red;

unit model Person is rw;
# this id is used to create unique registration numbers
# for various lists for easy use by humans
has UInt $!id       is id;

# note the following is for user-defined keys to maintain unique
# person status by personal attributes
has Str  $.key      is column{:unique};

# data:
has Str  $.last     is column;
has Str  $.first    is column;
has Str  $.notes    is column{:nullable};

# relations
has      @.attends  is relationship({.person-id}, :model<Attend>);
has      @.emails   is relationship({.person-id}, :model<Email>);
has      @.presents is relationship({.person-id}, :model<Present>);
