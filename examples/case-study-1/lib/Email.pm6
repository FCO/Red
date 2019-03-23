use Red;

#`{{{
        create table email_tbl (
                email      varchar(255) not null,
                notes      varchar(255),
                status     integer,
                person_id  integer references person_tbl(id)
        );
}}}

unit model Email is rw;

# data:
has Str  $.email     is column;
has Str  $.notes     is column{:nullable};
has UInt $.status    is column{:nullable};

# relationship
has UInt $!person-id is referencing{  :column<id>, :model<Person> };
has      $.person    is relationship{ :column<person-id>, :model<Person> };

=begin comment
# constraint
::?CLASS.^add-unique-constraint: { .person-id, .email };
=end comment
