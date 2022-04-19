use Test;
use Red;

plan :skip-all("Different driver setted ($_)") with %*ENV<RED_DATABASE>;
model PostTag {...}

model Post {
	has UInt    $.id        is serial;
	has Str     $.title     is unique;
	has PostTag @.post-tags is relationship{ .post-id };
	method tags { @.post-tags>>.tag }
}

model Tag {
	has Str $.name          is id;
	has PostTag @.post-tags is relationship{ .tag-id };
	method posts { @.post-tags>>.post }
}

model PostTag {
	has UInt $.post-id is column{ :id, :references{ .id },   :model-name<Post> };
	has Str  $.tag-id  is column{ :id, :references{ .name }, :model-name<Tag>  };
	has Post $.post    is relationship{ .post-id };
	has Tag  $.tag     is relationship{ .tag-id  };
}

my $*RED-FALLBACK       = $_ with %*ENV<RED_FALLBACK>;
my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my $*RED-DEBUG-AST      = $_ with %*ENV<RED_DEBUG_AST>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => val .[1] } } );

schema(PostTag, Post, Tag).create;

my $a = Post.^create: :title<bla>, :post-tags[{ :tag{ :name<a> } }, { :tag{ :name<b> } }];
my $b = Post.^create: :title<ble>, :post-tags[{ :tag{ :name<a> } }, { :tag{ :name<c> } }];

is $a.tags>>.name, <a b>;
is $b.tags>>.name, <a c>;
is Tag.^all.head.posts>>.title, <bla ble>;

done-testing
