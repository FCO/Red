use Red;

#`{{{
        create table person_tbl (
                id    integer serial,
                key   varchar(255) unique not null,
                last  varchar(255) not null,
                first varchar(255) not null
                notes varchar(255)
        );
}}}

unit model Person is rw;

# this id (primary key) is used to create unique registration numbers
# for various lists for easy use by humans
has UInt $.id       is serial;

# note the following is for user-defined keys to maintain unique
# person status by personal attributes
has Str  $.key      is column{:unique};

# data:
has Str  $.last     is column;
has Str  $.first    is column;
has Str  $.notes    is column{:nullable};

# relationships
has      @.attends  is relationship{ :column<person>, :model<Attend>  };
has      @.emails   is relationship{ :column<person-id>, :model<Email>   };
has      @.presents is relationship{ :column<person-id>, :model<Present> };
