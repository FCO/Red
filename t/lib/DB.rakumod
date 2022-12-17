use Red:api<2>;

unit module DB;

model CITestSet is rw is table<citest_set> {
    has UInt $.id    is serial;
    has Str $.status is column;
}
