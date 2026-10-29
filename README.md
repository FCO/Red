[![Build Status](https://github.com/FCO/Red/workflows/test/badge.svg)](https://github.com/FCO/Red/actions) [![SparrowCI](https://ci.sparrowhub.io/project/gh-FCO-Red/badge)](https://ci.sparrowhub.io)

Red
===

Take a look at our Documentation: [https://fco.github.io/Red/](https://fco.github.io/Red/)

Red - A **WiP** ORM for Raku
----------------------------

RECENT HIGHLIGHTS
-----------------

**PostgreSQL users: the Pg driver is no longer bundled with Red.** Install the separate `Red::Driver::Pg` distribution when installing or upgrading:

    zef install Red::Driver::Pg

Other recent highlights include:

  * **Queries:** opt-in RakuAST compilation, compiled regex filters translated to SQL, and isolated SQL plan caching. See [compiled regex filters](#compiled-regex-filters).

  * **Schema:** named, composite and partial indexes, `CHECK` and PostgreSQL `EXCLUDE` constraints, and native range/regex helpers. See [indexes and constraints](#named-indexes-and-schema-constraints) and [PostgreSQL ranges](#postgresql-ranges-regex-and-exclusion-constraints).

  * **Transactions:** nested savepoints and explicit guards with asynchronous work. See [transactions and savepoints](#transactions-and-savepoints).

  * **Models and relationships:** creation through empty scalar relationships, stable `has-one`, `.^refresh` and `is handling`, plus dirty tracking for in-place collection mutations. See [relationship creation](#creating-through-a-scalar-relationship), [refresh](#refresh) and [is handling](#is-handling).

  * **Results and JSON:** chainable scalar/container projections, SQL `tail`/`reverse`, `ResultSeq` products and expanded JSON operations.

  * **Performance and reliability:** faster hydration and projections, safer concurrent query/class initialization, and fixes for generated getters and formatter handling.

See [Changes](Changes) for the complete list.

INSTALL
-------

Install with (you need **rakudo 2018.12-94-g495ac7c00** or **newer**):

    zef install Red

PostgreSQL support is provided by a separate distribution. Install it only if you use PostgreSQL:

    zef install Red::Driver::Pg

SYNOPSIS
--------

```raku
use Red:api<2>;

model Person {...}

model Post is rw {
    has Int         $.id        is serial;
    has Int         $!author-id is referencing( *.id, :model(Person) );
    has Str         $.title     is column{ :unique };
    has Str         $.body      is column;
    has Person      $.author    is relationship{ .author-id };
    has Bool        $.deleted   is column = False;
    has DateTime    $.created   is column .= now;
    has Set         $.tags      is column{
        :type<string>,
        :deflate{ .keys.join: "," },
        :inflate{ set(.split: ",") }
    } = set();
    method delete { $!deleted = True; self.^save }
}

model Person is rw {
    has Int  $.id            is serial;
    has Str  $.name          is column;
    has Post @.posts         is relationship{ .author-id };
    method active-posts { @!posts.grep: not *.deleted }
}

my $*RED-DB = database "SQLite";

Person.^create-table;
```

```sql
-- Equivalent to the following query:
CREATE TABLE person(
    id integer NOT NULL primary key
    AUTOINCREMENT,
    name varchar(255) NOT NULL
)
```

```raku
Post.^create-table;
```

```sql
-- Equivalent to the following query:
CREATE TABLE post(
    id integer NOT NULL primary key AUTOINCREMENT,
    author_id integer NULL references person(id),
    title varchar(255) NOT NULL,
    body varchar(255) NOT NULL,
    deleted integer NOT NULL,
    created varchar(32) NOT NULL,
    tags varchar(255) NOT NULL,
    UNIQUE (title)
)
```

```raku
my Post $post1 = Post.^load: :42id;
```

```sql
-- Equivalent to the following query:
SELECT
    post.id,
    post.author_id as "author-id",
    post.title,
    post.body,
    post.deleted,
    post.created,
    post.tags
FROM
    post
WHERE
    post.id = 42
```

```raku
my Post $post1 = Post.^load: 42;
```

```sql
-- Equivalent to the following query:
SELECT
    post.id,
    post.author_id as "author-id",
    post.title,
    post.body,
    post.deleted,
    post.created,
    post.tags
FROM
    post
WHERE
    post.id = 42
```

```raku
my Post $post1 = Post.^load: :title("my title");
```

```sql
-- Equivalent to the following query:
SELECT
    post.id,
    post.author_id as "author-id",
    post.title,
    post.body,
    post.deleted,
    post.created,
    post.tags
FROM
    post
WHERE
    post.title = ‘my title’
```

```raku
my $person = Person.^create: :name<Fernando>;
```

```sql
-- Equivalent to the following query:
INSERT INTO person(
    name
)
VALUES(
    $1
) RETURNING *
-- BIND: ["Fernando"]
```

```raku
RETURNS:
Person.new(name => "Fernando")
```

```raku
say $person.posts;
```

```sql
-- Equivalent to the following query:
SELECT
    post.id,
    post.author_id as "author-id",
    post.title,
    post.body,
    post.deleted,
    post.created,
    post.tags
FROM
    post
WHERE
    post.author_id = ?
-- BIND: [1]
```

```raku
say Person.new(:2id)
    .active-posts
    .grep: { .created > now }
```

```sql
-- Equivalent to the following query:
SELECT
    post.id,
    post.author_id as "author-id",
    post.title,
    post.body,
    post.deleted,
    post.created,
    post.tags
FROM
    post
WHERE
    (
       post.author_id = ?
       AND (
           post.deleted == 0
           OR post.deleted IS NULL
       )
    )
    AND post.created > 1554246698.448671
-- BIND: [2]
```

```raku
my $now = now;
say Person.new(:3id)
    .active-posts
    .grep: { .created > $now }
```

```sql
-- Equivalent to the following query:
SELECT
    post.id,
    post.author_id as "author-id",
    post.title,
    post.body,
    post.deleted,
    post.created,
    post.tags
FROM
    post
WHERE
    (
       post.author_id = ?
       AND (
           post.deleted == 0
           OR post.deleted IS NULL
       )
    )
    AND post.created > ?
-- BIND: [
--   3,
--   Instant.from-posix(
--       <399441421363/257>,
--       Bool::False
--   )
-- ]
```

```raku
Person.^create:
    :name<Fernando>,
    :posts[
        {
            :title("My new post"),
            :body("A long post")
        },
    ]
;
```

```sql
-- Equivalent to the following query:
INSERT INTO person(
    name
)
VALUES(
    ?
) RETURNING *
-- BIND: ["Fernando"]

INSERT INTO post(
    created,
    title,
    author_id,
    tags,
    deleted,
    body
)
VALUES(
    ?,
    ?,
    ?,
    ?,
    ?,
    ?
) RETURNING *
-- BIND: [
--   "2019-04-02T22:55:13.658596+01:00",
--   "My new post",
--   1,
--   "",
--   Bool::False,
--   "A long post"
-- ]
```

```raku
my $post = Post.^load: :title("My new post");
```

```sql
-- Equivalent to the following query:
SELECT
    post.id,
    post.author_id as "author-id",
    post.title,
    post.body,
    post.deleted,
    post.created,
    post.tags
FROM
    post
WHERE
    post.title = ‘My new post’
-- BIND: []
```

```raku
RETURNS:
Post.new(
   title   => "My new post",
   body    => "A long post",
   deleted => 0,
   created => DateTime.new(
       2019,
       4,
       2,
       23,
       7,
       46.677388,
       :timezone(3600)
   ),
   tags    => Set.new("")
)
```

```raku
say $post.body;
```

```raku
PRINTS:
A long post
```

```raku
my $author = $post.author;
```

```raku
RETURNS:
Person.new(name => "Fernando")
```

```raku
$author.name = "John Doe";

$author.^save;
```

```sql
-- Equivalent to the following query:
UPDATE person SET
    name = ‘John Doe’
WHERE id = 1
```

```raku
$author.posts.create:
    :title("Second post"),
    :body("Another long post");
```

```sql
-- Equivalent to the following query:
INSERT INTO post(
    title,
    body,
    created,
    tags,
    deleted,
    author_id
)
VALUES(
    ?,
    ?,
    ?,
    ?,
    ?,
    ?
) RETURNING *
-- BIND: [
--   "Second post",
--   "Another long post",
--   "2019-04-02T23:28:09.346442+01:00",
--   "",
--   Bool::False,
--   1
-- ]
```

```raku
$author.posts.elems;
```

```sql
-- Equivalent to the following query:
SELECT
    count(*) as "data_1"
FROM
    post
WHERE
    post.author_id = ?
-- BIND: [1]
```

```raku
RETURNS:
2
```

DESCRIPTION
-----------

Red is a *WiP* ORM for Raku.

### traits

  * `is column`

  * `is column{}`

  * `is id`

  * `is id{}`

  * `is serial`

  * `is referencing{}`

  * `is relationship{}`

  * `is table<>`

  * `is nullable`

  * `is handling`

### features:

#### relationships

Red will infer relationship data if you use type constraints on your properties.

```raku
# Single file e.g. Schema.pm6

model Related { ... }


# belongs to
model MyModel {
    has Int     $!related-id is referencing( *.id, :model<Related> );
    has Related $.related    is relationship{ .id };
}

# has one/has many
model Related {
    has Int $.id is serial;
    has MyModel @.my-models is relationship{ .related-id };
}
```

If you want to put your schema into multiple files, you can create an "indirect" relationship, and Red will look up the related models as necessary.

```raku
# MyModel.pm6
model MyModel {
    has Int     $!related-id is referencing{ :model<Related>, :column<id> };
    has         $.related    is relationship({ .id }, :model<Related>);
}

# Related.pm6
model Related {
    has Int $.id is serial;
    has     @.my-models is relationship({ .related-id }, :model<MyModel>);
}
```

If Red can’t find where your `model` is defined you can override where it looks with `require`:

```raku
    has Int     $!related-id is referencing{ :model<Related>, :column<id>,
                                             :require<MyApp::Schema::Related> };
```

#### creating through a scalar relationship

An empty scalar relationship returns an undefined, false type object carrying the relationship's creation context, rather than `Nil`. Call `.^create` on that object to create the related row and fill the foreign key automatically:

```raku
my $parent = $child.parent.^create(:name<parent>);

# For a relationship declared with :has-one:
my $profile = $account.profile.^create(:description<profile>);
```

For a belongs-to relationship, Red saves the foreign key on the existing source row. For `:has-one`, Red supplies the source key to the new related row. The source must already be saved. Both writes participate in one transaction; a failed operation rolls back its writes and restores the source's attribute and dirty state. Inside a transaction, the operation uses a savepoint.

Existing relationships continue to return their related instances. An empty relationship still tests false and undefined, but code that checks specifically for `Nil` should use `.defined` instead. Creation uses `.^create`, while plural relationships continue to use `.create`.

#### named indexes and schema constraints

Independent schema declarations use ordinary attributes that do not become columns or appear in row data. Existing `is indexed`, `is unique`, `is index{...}` and `is unique-index{...}` forms remain supported.

```raku
model Measurement {
    has UInt $.id is serial;
    has Rat $.percent is column;
    has Str $.name is column;
    has Int $.active is column;

    has $!percent-valid is check{ sql-and(.percent >= 0, .percent <= 1) };
    has $!name-tree is index({ .name }, :using<btree>);
    has $!name-search is index({ .name },
        :using<gin>, :opclass<gin_trgm_ops>, :driver<Pg>);
    has $!active-name is unique-index({ .name },
        :where{ .active == 1 }, :driver<Pg>);
}
```

`:using` selects an access method. PostgreSQL supports `btree`, `hash`, `gin`, `gist`, `spgist` and `brin`; the common API supports `btree`. `:opclass` selects a PostgreSQL operator class. For multiple keys, supply a list with one string per key, using an empty string for the default class. A class can be qualified with its schema. `:where` defines a partial index on PostgreSQL or SQLite; MySQL rejects an unguarded partial index.

`:driver<Pg>` explicitly selects a declaration only for that backend. The names are `Pg`, `SQLite` and `MySQL`, or a custom driver's final class-name component. Without this option an unsupported declaration raises `X::Red::Index`; Red does not substitute another index method or weaken a constraint. Conditional constraints are intentionally absent on the other backends.

`CHECK` is included by `.^create-table` and `schema.create` and is enforced by the database for both inserts and updates, including writes outside Red. Use `sql-and`, `sql-or` and `sql-not` for compound predicates. Raku's short-circuit `&&` and `||` are rejected in schema predicates rather than changing SQL's three-valued logic. SQL's usual NULL semantics apply: a CHECK is not a substitute for NOT NULL.

`.^create-indexes` adds indexes to existing tables and checks existing names, key order, uniqueness, access method, operator classes and partial predicates. It rejects incompatible definitions instead of silently accepting them. It does not add or alter CHECK or EXCLUDE constraints on an existing table; those require an explicit schema migration.

#### Compiled regex filters

Red exports the optional compiler. On the RakuAST frontend, invoke it at CHECK:

```raku
use Red:api<2>;
CHECK red-compile;

my @users = User.^all.grep({ .name ~~ /^ 'Ana'/ });
my @codes = User.^all.grep({ .code ~~ /:i ^ <[a..z]>+ \d ** 2 $/ });
```

Recent Rakudo versions may use RakuAST by default. Set `RAKUDO_RAKUAST=1` only when selecting it is necessary; the frontend alone does not enable `red-compile`.

Regex literals in `grep` and `first` are compiled to SQL, including single `.match(/.../)` predicates and regex callables on scalar projections. PostgreSQL uses its ARE engine and MySQL 8 uses `REGEXP_LIKE`. SQLite rejects regex by default; opt in with `database "SQLite", :use-experimental-regex`. Its experimental implementation uses string operations for literal-only patterns or a recursive SQL state machine for general patterns, without an extension or Raku callback. Pattern data are bound as parameters. Primitive numeric inputs use SQL text formatting; Boolean inputs retain Raku's `True`/`False` spelling. Direct nullable columns and unsupported composite/custom stringifiers are rejected.

The supported core includes literals, string/line/word anchors, groups, alternatives, positive and negative character classes, static Unicode properties, static `E<lt>at(n)E<gt>` positions, Boolean Match markers, greedy/frugal quantifiers, open/finite repetition bounds, separators, `:s` significant whitespace and lookarounds. Nonrecursive lexical regex rules without parameters, traits or phasers can be expanded from their syntax tree. `token` and `rule` declarations are also expanded when their operations are supported by the chosen engine. MySQL supports ratcheted quantifiers through atomic matching; PostgreSQL and SQLite reject operations requiring that lowering. Regular conjunctions `&` and `&&` use a product automaton, preserving the common matched span. Native conjunction lowering has a 128-state/64KiB pattern limit. Case modifiers work at the root on all three engines; scoped case modifiers also work on MySQL and SQLite. PostgreSQL bounds above 255 are lowered into smaller native blocks, subject to pattern expansion and capture limits. SQLite limits each compiled state machine to 4096 states.

Positional capture references are supported by PostgreSQL and MySQL within engine limits. MySQL keeps capture references exact under `:i`; PostgreSQL rejects references in that case mode. MySQL supports references within a lookahead's own capture scope; PostgreSQL and SQLite reject those references. Local scalar references survive repeated group/rule scopes; repeated capture-list references are rejected; Raku capture lists cannot be replaced by a single native backreference. SQLite rejects regex backreferences. PostgreSQL supports guarded scalar capture text comparisons with `$0`, literal named captures and `$/` after a direct regex condition, including predicate `if`/`unless` modifiers. Quote spaces that must match input. Missing captures produce SQL NULL; capture arrays and Match object methods remain unsupported. MySQL 8.0.17+ also supports whole-match `$/` text using `REGEXP_SUBSTR`, with exact case and trailing-space comparison. Whole-match `$/.defined` and `$/.Bool` work on all matching backends. PostgreSQL also supports scalar capture presence via `.defined`, `.Bool` and Boolean `:exists`, preserving empty versus absent groups. No Raku Match object is returned or populated.

Matching uses database character/collation semantics, so normalization, grapheme boundaries and case folding can differ from Raku. Static Unicode properties use the compiling Rakudo's Unicode data. Literal scalar/array interpolation is bound once as escaped data; it does not evaluate regex source. Interpolation inside inlined named rules is rejected until their closure frames can be retained safely. SQLite's built-in case folding and shorthand classes are ASCII-oriented. SQL NULL semantics apply to expressions producing NULL; text containing NUL is outside the supported domain.

Unsupported regex syntax and unavailable driver features throw a fatal `X::Red::Compiler::Unsupported` diagnostic, even if `$*RED-FALLBACK` is enabled. Code blocks, executable regex interpolation, recursive grammars and unsupported capture behavior are never silently replaced with in-memory filtering. Ordinary Raku collections retain their normal regex behavior. See `docs/regex-support.md` for the driver matrix and remaining work.

#### PostgreSQL ranges, regex and exclusion constraints

`sql-operator` builds an AST for PostgreSQL range and regex operators such as `@> `, `<@ `, `&&` and `~*`. Values are bound in queries and quoted as literals in schema DDL. `sql-range` builds a native range constructor, defaulting to `numrange` with `[)` bounds. Its `:type` can also select `int4range`, `int8range`, `tsrange`, `tstzrange` or `daterange`.

```raku
model TrackSegment {
    has UInt $.id is serial;
    has Int $.track-id is column;
    has Str $.percent-range is column{ :type<numrange> };

    has $!range-valid is check(
        { sql-operator('@>', sql-range(0, 1, :bounds<[]>), .percent-range) },
        :driver<Pg>
    );
    has $!no-overlap is exclude(
        { .track-id => '=', .percent-range => '&&' },
        :using<gist>, :driver<Pg>
    );
}

my @segments = TrackSegment.^all.grep({
    sql-operator('&&', .percent-range, sql-range(0.2, 0.4))
});
```

The exclusion constraint rejects overlapping ranges on the same track. Native range columns and operators require PostgreSQL. Bounds containment permits empty ranges; reject them with a separate constraint if the domain requires it. Applications must provision needed extensions explicitly: `pg_trgm` supplies `gin_trgm_ops`, and `btree_gist` supplies GiST classes for scalar keys such as the integer track identifier. Red does not install extensions automatically.

#### custom table name

```raku
model MyModel is table<custom_table_name> {}
```

#### not nullable columns by default

Red, by default, has not nullable columns, to change it:

```raku
#| This makes this model’s columns nullable by default
model MyModel is nullable {
    has Int $.col1 is column;               #= this column is nullable
    has Int $.col2 is column{ :!nullable }; #= this one is not nullable
}
```

#### load object from database

```raku
MyModel.^load: 42;
MyModel.^load: id => 42;
```

#### save object on the database

```raku
$object.^save;
```

#### search for a list of object

```raku
Question.^all.grep: { .answer == 42 }; # returns a result seq
```

#### transactions and savepoints

`red-do :transaction` commits when its block succeeds and rolls back when it fails. Nested transactional blocks on the same connection use savepoints. They can see uncommitted outer changes, and their successful changes remain subject to an outer rollback. Catch an inner exception to roll back only that inner block and continue the outer transaction; an exception that propagates out rolls back the outer block too.

```raku
red-do :transaction, {
    Person.^create: :name<Alice>;
    try {
        red-do :transaction, {
            Person.^create: :name<Bob>;
            # A failure here rolls back Bob, leaving Alice in the outer transaction.
        }
    }
};
```

Drivers provide `savepoint($name)`, `rollback-to-savepoint($name)` and `release-savepoint($name)` on the current connection. Rolling back to a savepoint leaves that savepoint active; releasing it does not commit the surrounding transaction. Savepoints do not coordinate concurrent tasks. Await asynchronous database work before leaving an automatic transactional block, and avoid overlapping access to its connection.

##### Explicit transaction guards

Declare a named `:$guard` parameter to take explicit control of a transaction. The block receives a `Red::Transaction::Guard`; a positional parameter, if declared, still receives the transaction's driver. A slurpy named parameter alone does not enable manual control. Blocks that declare neither `:$guard` nor the named placeholder `$:guard` retain automatic commit and rollback. Automatic scopes retain Raku's `KEEP`/`UNDO` behavior: a nonlocal `return` or `fail` unwinds the scope and rolls it back.

```raku
my $work = red-do :transaction, -> :$guard! {
    $guard.start: -> :&commit {
        Person.^create: :name<Alice>;
        commit();
    }
};
await $work;
```

You can also use Raku's named placeholder `$:guard` instead of writing `-` :$guard!>. Using it inside a block implicitly declares the required named parameter, so `red-do` recognizes it as a manual transaction. Both direct commit and asynchronous work are supported:

```raku
red-do :transaction, {
    Person.^create: :name<Alice>;
    $:guard.commit;
};

my $work = red-do :transaction, {
    $:guard.start: -> :&commit {
        Person.^create: :name<Bob>;
        commit();
    }
};
await $work;
```

Each guard starts with one participant, which `red-do` releases automatically when its block exits, including with `:async`. The last release rolls back an unfinished scope. Do not release that initial participant yourself.

`.do(&block)` reserves a participant, runs the block immediately and releases when it finishes, returning its result. `.start(&block)` reserves before scheduling and returns a Promise; completion releases the participant. Failed scheduling returns the reservation. Both restore the guard's transaction context and inject `:&commit` and `:&rollback` only when explicitly declared in the block's signature. An escaping exception immediately rolls back and propagates (breaking the Promise for `.start`). A Promise returned by `.do` does not extend its participation; use `.start` for asynchronous work. Returning a pending Promise from `.do` emits `X::Red::Transaction::AsyncResult`, a resumable warning that suggests `.start` without awaiting or replacing the result. Already completed Promises do not warn. To silence an intentional pending result, handle this type in `CONTROL` and call `.resume`.

For explicit lifetime control, `retain()` adds a participant and `release()` removes one. Both return the guard. Each additional participant must be released exactly once. To use a guard after its `red-do` block returns, retain it or schedule work with `.start` before exiting. For manually scheduled work, reserve before scheduling, release in its `LEAVE`, and return the reservation if scheduling fails.

`commit()` confirms immediately, without waiting for participants. Explicit `rollback()` and exceptions escaping the block also close an open scope immediately. Pending participants must still release after closure; these releases execute no SQL. Retaining a closed guard, releasing with no remaining participants, or committing a closed guard raises `X::Red::Transaction`. Explicit rollback remains idempotent. An exception after commit cannot undo it. Garbage collection provides no cleanup guarantee.

A nested guard controls a savepoint with its own participant count. Its last release rolls back only that savepoint. Its parent cannot run queries, open another child, or commit until that child closes. Parent rollback also invalidates all descendants. Drivers, statements, iterators and lazy queries belonging to a closed scope reject further database access. Ordinary driver use outside the scope is unaffected; direct access to a native database handle bypasses these guards.

Guards keep the reserved session usable by asynchronous work that inherits the block's context. Participant bookkeeping is synchronized, but does not permit simultaneous database operations: overlapping database access is rejected with `X::Red::Transaction`. No returned Promise is required to retain a manual transaction. With `:async`, an automatic transaction's Promise resolves after commit; a manual transaction's Promise represents only execution of its block, not guard completion.

#### phasers

  * `before-create`

  * `after-create`

  * `before-update`

  * `after-update`

  * `before-delete`

  * `after-delete`

#### Temporary table

```raku
model Bla is temp { ... }
```

#### is handling

The `is handling` trait "exports" `ResultSeq` methods to the model itself, so they can be called directly on the model's type object. Each positional value is the name of a `ResultSeq` method to expose; passing a pair renames it:

```raku
model Bla is handling<map grep> { has Int $.a is column }

Bla.map(*.a);              # same as Bla.^all.map(*.a)
Bla.grep(*.a < 5);         # same as Bla.^all.grep(*.a < 5)

model Ble is handling(map => "update", grep => "where") { has Int $.a is column }

Ble.update(*.a);           # same as Ble.^all.map(*.a), renamed
Ble.where(*.a < 5);        # same as Ble.^all.grep(*.a < 5), renamed
```

#### refresh

The `.^refresh` meta-method reloads a model instance's columns with the actual data from the database. It accepts a list of column (attribute) names, or nothing at all to refresh every column:

```raku
my $post = Post.^load: 42;
# ... some external process updates the row ...
$post.^refresh;                # refreshes all columns
$post.^refresh: "title";       # refreshes only the "title" column
$post.^refresh: <title body>;  # refreshes "title" and "body"
```

Refreshed columns are also marked clean on the model's dirty tracking.

#### Create table

```raku
Question.^create-table;
Question.^create-table: :if-not-exists;
Question.^create-table: :unless-exists;
```

#### IN

```raku
Question.^all.grep: *.answer ⊂ (3.14, 13, 42)
```

#### create

```raku
Post.^create: :body("bla ble bli blo blu"), :title("qwer");


model Tree {
    has UInt   $!id        is id;
    has Str    $.value     is column;
    has UInt   $!parent-id is referencing{ Tree.id };

    has Tree   $.parent    is relationship{ .parent-id };
    has Tree   @.kids      is relationship{ .parent-id };
}

Tree.^create-table: :if-not-exists;

Tree.^create:
    :value<Bla>,
    :parent{:value<Ble>},
    :kids[
        {:value<Bli>},
        {:value<Blo>},
        {:value<Blu>}
    ]
;
```

AUTHOR
------

Fernando Correa de Oliveira <fernandocorrea@gmail.com>

COPYRIGHT AND LICENSE
---------------------

Copyright 2018 Fernando Correa de Oliveira

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

