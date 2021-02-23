use v6;
use Red;

model Post is rw {
    has Int         $.id        is serial;
    has Int         $.author-id is referencing(model => 'Person', column => 'id' );
    has Str         $.title     is column{ :unique };
    has Str         $.body      is column;
    has             $.author    is relationship({ .author-id }, model => 'Person');
}
