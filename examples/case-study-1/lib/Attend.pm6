use Red;

#`{{{
        create table attend_tbl (
                year       integer not null,
                notes      varchar(255),
                person_id  integer references person_tbl(id)
        );
}}}

unit model Attend is rw;

# data:
has UInt $.year      is column;
has Str  $.notes     is column{:nullable};

# foreign key
has UInt $.person    is referencing{ :column<id>, :model<Person> };

# Red relationship
#has      $.person-id is relationship{ :column<id>, :model<Person> };
