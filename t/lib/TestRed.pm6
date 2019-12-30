use Red;

model Foo { ... }

model Zub is rw {
    has Int $.id is serial;
    has Int $.default-foo-id is referencing( *.id, :model<Foo>, :require<TestRed> );
    has Foo $.default-foo is relationship( { .default-foo-id });
    has Foo @.foos is relationship( { .zub-id });
}

model Foo  is rw {
    has Int $.id is serial;
    has Str $.bar is column;
    has Int $.zub-id is referencing( *.id, :model<Zub>, :require<TestRed> );
    has Zub $.zub is relationship( { .zub-id });
}
