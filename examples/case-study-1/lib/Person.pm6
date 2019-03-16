use Red;

unit model Person is rw;

# note the following is for user-defined keys
has Str $key     is id;

# data:
has Str $.last   is column;
has Str $.first  is column;
has Str $.notes  is column{:nullable};

# relations
has   @.attends  is relationship({.person-id }, :model<Attend>);
has   @.emails   is relationship({.person-id }, :model<Email>);
has   @.presents is relationship({.person-id }, :model<Present>);
