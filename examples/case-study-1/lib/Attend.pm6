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
has UInt $.person    is referencing{ :column<id>, :model<Person> };

# relationship
has      $.person-id is relationship{ :column<id>, :model<Person> };

=begin comment
# constraint
::?CLASS.^add-unique-constraint: { .person-id, .year };
=end comment
