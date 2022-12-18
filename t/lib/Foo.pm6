use Red;

model Foo is table('foo') {
	has Str $.a is column;
	has Str $.b is column;
	has Str $.c is column;
	has Date $.foo-date is column = Date.today;
}

