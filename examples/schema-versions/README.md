# An existing project with three schema versions

This is a project a new developer can clone and use immediately. Its current
models describe v3; its complete prepared migration history is already committed.
No preparation or helper script is needed. Requires Raku, Red's dependencies
(`zef install --/test --test-depends --deps-only .` from the repository root),
and the sqlite3 command-line client.

Run commands below from `examples/schema-versions`. Within this checkout, replace
`red` with `raku -I../../lib ../../bin/red` to use the repository's CLI.
The SQLite connection creates `example.db` here; it is ignored by Git.

| Version | Application tables |
| --- | --- |
| v1 | project (id, name) |
| v2 | project, task (id, title, project_id → project.id) |
| v3 | project, task, comment (id, body, task_id → task.id) |

## First checkout

```sh
red migration status
red migration apply
red migration status
sqlite3 example.db '.schema'
sqlite3 example.db '.tables'
```

Before application, status reports an uninitialized database. Apply executes all
three migrations. A second apply reports zero work. Red also maintains its own
migration bookkeeping tables.

## Load fixtures

Three named fixtures provide 3 projects, 4 tasks and 3 comments. Apply them in
this order on a fresh v3 database:

```sh
red fixture list
red fixture apply projects
red fixture apply tasks
red fixture apply comments
sqlite3 -header -column example.db 'SELECT * FROM project; SELECT * FROM task; SELECT * FROM comment;'
```

At v1 apply only `projects`. At v2 apply `projects`, then `tasks`. At v3 all
three are available. Tasks reference the projects; comments reference the tasks.
Fixtures use fixed IDs: apply each only once while its records are present.
Applying an existing fixture again fails on duplicate IDs; it does not replace
or clear existing records. Fixtures run in a transaction.

## Go backward and forward

```sh
# v3 -> v2: drops comment, including its data.
red migration rollback
sqlite3 example.db '.schema'
sqlite3 example.db 'SELECT * FROM task;'

# v2 -> v1: drops task; project remains with its data.
red migration rollback
sqlite3 example.db '.schema'
sqlite3 example.db 'SELECT * FROM project;'

# v1 -> v3: recreates task and comment, now empty.
red migration apply
red migration status
sqlite3 example.db 'SELECT * FROM project; SELECT * FROM task; SELECT * FROM comment;'
```

Models in `lib/` always represent v3. Use SQL to inspect older schemas; querying
newer models against an older schema can fail. Rollback restores structure, not
lost records. The up/down SQL and snapshots are available under `migrations/`.

## Apply only part of the history

On a fresh database, or after rolling back all three versions:

```sh
red migration apply --to=01M6T0BGTRR7RD5PM7CB578945
sqlite3 example.db '.schema'
red migration apply --to=01M6T0BGTRMVJEEHW0WTY0930S
sqlite3 example.db '.schema'
red migration apply
```

`--to` limits forward application; use rollback to move backward. Rolling back
v1 also removes project and its records. Inspect `red migration status` before
each rollback to see the current version.

## Restore data after rollback

After the v3 → v2 → v1 → v3 sequence above, projects still exist. Reload only
the fixtures for the tables that were dropped:

```sh
red fixture apply tasks
red fixture apply comments
sqlite3 -header -column example.db 'SELECT p.name, t.title, c.body FROM project p LEFT JOIN task t ON t.project_id = p.id LEFT JOIN comment c ON c.task_id = t.id ORDER BY p.id, t.id, c.id;'
```

If you only roll back v3 to v2 and apply again, reload only `comments`.
If you roll back all three migrations and apply again, reload all three fixtures.
Migrations never load fixtures automatically.
