use Red:api<2>;

model IndexedFixture {
    has Int $.id is serial;
    has Str $.email is indexed{ .lc };
    has Str $.code is unique;
    has $.email-key is unique-index{ .email.lc };
}
