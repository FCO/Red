use Red;

model Foo { ... }

model Zub is rw {
    has Int $.id is serial;
    has Int $.default-foo-id is referencing( { Foo.id } );
    has Foo $.default-foo is relationship( { .default-foo-id });
    has Foo @.foos is relationship( { .zub-id });
}

model Foo  is rw {
    has Int $.id is serial;
    has Str $.bar is column;
    has Int $.zub-id is referencing( { Zub.id } );
    has Zub $.zub is relationship( { .zub-id });
}
