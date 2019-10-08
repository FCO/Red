use Test;
use Red;

model Person { ... }

model Post {
    has UInt     $!id        is serial;
has Str      $.title     is column{ :unique };
has Str      $.body      is column;
has UInt     $.author-id is referencing{ Person.id };
has Person   $.author    is relationship{ .author-id };
has DateTime $.created   is column .= now;
has DateTime $.published is column{ :nullable };
has DateTime $.deleted   is column{ :nullable };

method is-published {
    !self.deleted.defined and self.published.defined
}
method publish {
    $!published .= now;
    $!deleted    = Nil;
    self.^save
}
}

model Person {
    has UInt $!id    is serial;
has Str  $.name  is column;
has Str  $.email is column{ :unique };
has Post @.posts is relationship{ .author-id };
}

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my $*RED-DB             = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);


Post.^create-table;
Person.^create-table;

my $a1 = Post.^create: :title<Bla>, :body<Ble>, :published(DateTime.now);
my $a2 = Post.^create: :title<Bli>, :body<Blo>;
my $a3 = Post.^create: :title<Pla>, :body<Ple>, :published(DateTime.now.later(:1sec));
my $a4 = Post.^create: :title<Pli>, :body<Plo>, :published(DateTime.now.later(:2sec)), :deleted(DateTime.now);

my @posts := Post.^all;
is @posts.map(*.title).Seq, <Bla Bli Pla Pli>;
is @posts.grep(*.is-published).sort(*.published).map(*.title).Seq, <Bla Pla>;
is @posts.sort(*.title).batch(2)[0].map(*.title).Seq, <Bla Bli>;
is @posts.sort(*.title).batch(2)[1].map(*.title).Seq, <Pla Pli>;

#is @posts.classify(*.published.year).keys.Seq, <2019>;

done-testing;
