use lib "lib";
use Red;

model Person {...}

model Post is rw {
    has Int     $.id        is id;
    has Int     $!author-id is referencing{ Person.id };
    has Str     $.title     is column{ :unique };
    has Str     $.body      is column;
    has Person  $.author    is relationship{ .author-id };
    has Bool    $.deleted   is column = False;
    method delete { $!deleted = True; self.^save }
}

model Person is rw {
    has Int  $.id            is id;
    has Str  $.name          is column;
    has Post @.posts         is relationship{ .author-id };
    method active-posts { @!posts.grep: not *.deleted }
}

my $*RED-DEBUG = True;
my $*RED-DB = database "SQLite";

Person.^create-table;
Post.^create-table;

my $p  = Person.^create: :1id, :name<Fernando>;

my $post = $p.posts.create: :1id, :title<Bla>, :body<BlaBle1>;

$p.posts.create: :2id, :title<Ble>, :body<BlaBle2>;

say $p.posts.map: *.title;

$post.delete;

say $p.active-posts.map: *.id;
