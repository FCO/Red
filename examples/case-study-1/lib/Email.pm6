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

# foreign key
has UInt $.person    is referencing{  :column<id>, :model<Person> };

# Red relationship
has      $.person-id is relationship{ :column<id>, :model<Person> };
