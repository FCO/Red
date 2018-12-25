use Red;

model Post is rw {
    has Int         $.id        is serial;
    has Int         $.author-id is referencing(model => 'Person', key => 'id' );
    has Str         $.title     is column{ :unique };
    has Str         $.body      is column;
    has             $.author    is relationship({ .author-id }, model => 'Person');
}

