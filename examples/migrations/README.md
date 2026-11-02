# A migration workshop: code stages, databases and releases

This workshop supplies the application code automatically. The dev image contains
step 1; starting a fresh dev container copies that code into your workspace.
You prepare and apply migrations with `red`, deploy the application, then run
`./tutorial next` to construct the next code stage. No Git repository is required.

All project commands below run **inside the dev image**. The host only needs Docker
and Compose v2 to build, start, enter and stop containers. The image includes Raku,
Red, the Pg driver, Cro, nvim, curl, psql, test tools, and Docker CLI with Compose.
The example's source, comments, scripts and output are in English.

## Before starting

Start in `examples/migrations` in the Red checkout. The application lives only in
the dev container, at `/workspace`; parallel versions live at `/parallel`.
Edit files with nvim inside dev. No project directory is mounted from the host.
Use a different `COMPOSE_PROJECT_NAME` and ports for an independent exercise.
If you have already run an earlier version, use the full reset at the end of this
document before starting again; recreating code alone does not empty the databases.

The default Compose project name is `red-workshop`. Default startup runs `dev`,
`db-dev` and `db-prod`. Production is opt-in and its image is built during deploy;
no Docker registry login is needed. The two PostgreSQL services have independent
persistent volumes. These are local workshop databases with example credentials.

Dev uses the host Docker socket to manage CI and production. The helper sends the
container's current project files as a Docker build context. CI validates that image,
and production runs its copied code. Neither service needs a host project mount.

`red.rakuconf` uses `config { ... }` from `Red::Migration::Configuration`. Application
queries use the configured default connection automatically; `schema()` uses the configured
models. Its test uses `set-config -> { config { ... } }` to select the temporary test
connection. Connection factories remain lazy and are reused per thread.

CI executes the marked document blocks: one bootstrap block on the host followed
by ten steps in a single dev shell. Every required block includes checks. Optional
inspection commands are unmarked. The scripts do not silently generate or apply
migrations when advancing the application's code.

## 1. Start with the first code stage already supplied

**On the host**, in this directory:

<!-- workshop:run host -->
```bash
docker compose build dev
docker compose up -d --wait
```

Enter dev from the host:

```bash
docker compose exec dev bash
```

**Inside dev**, the workspace and the `workshop` helper are ready to use.
No aliases, shared-file permissions or shell setup are needed.
Verification commands use `workshop check`: each prints `ok - ...` or `nok - ...`
with an explanation. A failed check returns a nonzero exit status; stop and inspect
the failure before continuing.

<!-- workshop:run dev -->
```bash
cd /workspace
./tutorial status
red migration status
cat lib/Task.rakumod
cat red.rakuconf
```

**Expected:** `Current step: 1 (main)`, a Task with `id` and `title`, application and
test files, and two empty databases. The image initialized the code, not the schema.
The startup healthcheck waits until initialization is complete. Restarting the
same container preserves the current stage, local edits and generated migration files.
If status shows step 2 or 3, this is an existing exercise: resume from that code
stage rather than replaying the chapter that advances to step 2. Rebuilding the
image and recreating dev supplies fresh step-1 files. Database volumes persist until
explicitly removed. To replay the entire exercise, use the reset instructions below.

**Inspect:** `nvim lib/Task.rakumod`, `cat app.raku`, and
`cat .tutorial-state.json`. The state file records the code stage and hashes of
managed files; it is separate from the migration history stored in the database.
Do not edit the state file to skip stages.

From a second host terminal, enter another dev shell with
`docker compose exec dev bash`, then inspect the databases inside that shell:

```bash
red connect
# In psql: \dt lists tables; \q exits.
red connect --connection=production
```

## 2. Create the first migration and apply it in development

**Purpose:** distinguish code, prepared files and database state. The code exists
already; `prepare` creates migration artifacts without opening the target database.

<!-- workshop:run dev -->
```bash
cd /workspace
red migration plan
red migration prepare initial
find migrations -type f | sort
cat migrations/*/migration.rakuconf
cat migrations/*/Pg/up/001-schema.sql
cat migrations/*/Pg/down/001-schema.sql
workshop check "Prepare leaves the development database empty" test "$(workshop compose exec -T db-dev psql -U postgres -d tasks -Atc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'")" = 0
red migration apply
red migration status
red migration init-tests
red migration apply --test --driver=Pg -- raku -Ilib t/application.rakutest
workshop check "Application tests leave development data untouched" test "$(workshop compose exec -T db-dev psql -U postgres -d tasks -Atc 'SELECT count(*) FROM task')" = 0
```

**Expected:** prepare leaves dev empty. Apply creates `task`, `red_migrations` and
`red_migration_files`. Before apply, `red migration status` reports `Not initialized`
and lists the configured Task model and its columns without creating those tables.
The manifest links to its predecessor; snapshots describe
the schema, while numbered up/down files contain execution instructions.

**Verify:** inspect both history tables through psql. The round-trip application
test ran on a unique temporary database and left dev's task table empty.
`red migration init-tests` adds the standard migration test for application CI.

If apply reports that `task` already exists while migration status lists the initial
version as pending, stop and inspect the history. An existing table without a matching
applied record is not adopted automatically. Passing `apply --test` confirms the
scripts work on a fresh test database; it does not reconcile development's existing
schema or restore missing history records. Preserve that database before recovery.

## 3. Run the development application and create data

**Purpose:** observe persisted application data. `/` lists tasks and contains a
form; `/health` is a readiness endpoint, and `/version` identifies a release.

<!-- workshop:run dev -->
```bash
cd /workspace
workshop start
curl -fsS -X POST --data-urlencode 'title=Development task' http://dev:8080/tasks
curl -fsS http://dev:8080/ | grep 'Development task'
workshop check "Production is still empty before deployment" test "$(workshop compose exec -T db-prod psql -U postgres -d tasks -Atc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'")" = 0
```

**Expected:** dev lists its task; production still has no application tables.
You may also open `http://localhost:8081/` in the host browser. All command-line
HTTP checks use service names from inside the image.

## 4. Deploy the first release with the deployment helper

**Purpose:** validate, package and deploy the exact prepared migration history.
`workshop deploy v1` builds the release image, validates it through CI, stops the old production
application if present, runs `red migration apply` against production, and starts the release.
It stops at the first failing command. It never prepares migrations for you.

<!-- workshop:run dev -->
```bash
cd /workspace
workshop deploy v1
curl -fsS -X POST --data-urlencode 'title=Production task' http://prod:8080/tasks
curl -fsS http://prod:8080/ | grep 'Production task'
workshop check "Production runs release v1" test "$(curl -fsS http://prod:8080/version)" = v1
workshop check "Production contains its own task" test "$(workshop compose exec -T db-prod psql -U postgres -d tasks -Atc 'SELECT count(*) FROM task')" = 1
```

**Expected:** production has its own task at `http://localhost:8082/`. Editing the
dev workspace does not change the deployed code. CI uses `db-dev` as a server for
unique disposable test databases and never applies test migrations to production.
The helper uses a simple deployment with downtime, not a rolling deployment.

**Inspect:** `workshop compose logs prod`, `red migration status --connection=production`, and the release
image shown by `workshop compose ps`. Keep old images to coordinate application/schema rollback.

## 5. Construct step 2 and prepare its migration

**Purpose:** let the script add a required description field, preserving migration
files and databases. `./tutorial preview` shows the next model. `./tutorial next`
asks for Enter before writing; `--yes` below advances without an interactive pause.
`--to=2` makes repeating this chapter safe: it keeps an existing step 2 unchanged
and refuses a workspace already at step 3.
The script refuses to overwrite edits to managed code files. It preserves additional
files and all migrations. It does not change an already running Raku process.

<!-- workshop:run dev -->
```bash
cd /workspace
./tutorial preview --to=2
./tutorial next --to=2 --yes
./tutorial status
# EXPECTED ERROR: the model changed, but its migration has not been prepared yet.
# Expect "Migrated database does not match configured models"; the wrapper checks this failure.
workshop expect-failure 'Migrated database does not match configured models' workshop compose run --rm ci
red migration create add-description
second="migrations/$(workshop migration-id add-description)-add-description"
cat "$second/migration.raku"
cat > "$second/migration.raku" <<'RAKU'
Task.^migration: {
    $_ = 'Created before descriptions' without .description;
};
RAKU
red migration prepare add-description
cat "$second/Pg/up/001-structure.sql"
cat "$second/Pg/up/002-data.sql"
cat "$second/Pg/up/003-constraints.sql"
cat "$second/Pg/down/001-schema.sql"
# Review: this structural down removes the newly added description column.
# Mark the reviewed inverse available before CI and the first execution.
raku -e '
use MONKEY-SEE-NO-EVAL;
use Red::Migration::Artifact;
my $file = @*ARGS[0].IO;
my %manifest = EVALFILE($file.Str);
%manifest<drivers><Pg><down-state> = "available";
%manifest<drivers><Pg><reversible> = True;
%manifest<drivers><Pg><down-reason> = "";
$file.spurt(artifact-source("manifest", %manifest));
' "$second/migration.rakuconf"
red migration apply --test --driver=Pg -- raku -Ilib t/application.rakutest
red migration apply
workshop check "Existing development tasks receive a description" test "$(workshop compose exec -T db-dev psql -U postgres -d tasks -Atc 'SELECT description FROM task')" = 'Created before descriptions'
workshop check "Production remains on release v1" test "$(curl -fsS http://prod:8080/version)" = v1
```

**Expected:** step 2 is constructed automatically. CI initially refuses the code
because its migration is missing. Create supplies the historical data template.
Prepare produces ordered SQL that adds nullable storage, fills descriptions and
then enforces NOT NULL. Apply executes the complete migration synchronously.
The down SQL is reviewed explicitly before CI. The existing-data check verifies an
upgrade, while CI verifies a fresh database. Production remains on release v1.

The source and snapshots belong in version control. Do not edit executed migration
SQL or its frozen source. The code-stage script never replaces migration files.
Application processes retain their loaded models until restarted; CLI commands
load the current model immediately. Schema migration and application deployment
must be coordinated; there is no background worker or automatic online transition.

## 6. Deploy v2, roll back, and reapply

**Purpose:** preserve production data while coordinating application and schema
versions. Checking out code is not involved; release images retain previous code.
Rollback removes structure, not arbitrary lost data. `workshop rollback v2 v1`
stops v2, runs `red migration rollback` against production, then starts the v1 image.

<!-- workshop:run dev -->
```bash
cd /workspace
workshop deploy v2
workshop check "Production runs release v2" test "$(curl -fsS http://prod:8080/version)" = v2
workshop check "Existing production tasks receive a description" test "$(workshop compose exec -T db-prod psql -U postgres -d tasks -Atc 'SELECT description FROM task')" = 'Created before descriptions'
workshop rollback v2 v1
curl -fsS http://prod:8080/ | grep 'Production task'
workshop check "Rollback removes the description column" test "$(workshop compose exec -T db-prod psql -U postgres -d tasks -Atc "SELECT count(*) FROM information_schema.columns WHERE table_name='task' AND column_name='description'")" = 0
workshop deploy v2
```

**Expected:** v2 adds descriptions without losing the production task. Reverting the
migration and restarting v1 restores the previous shape. Redeploying v2 reapplies
its recorded migration. Inspect production history with `red migration status --connection=production`.

## 7. Construct two independent versions without Git

**Purpose:** simulate parallel development using independent directories. The script
copies the shared step-2 code and migrations, then supplies different step-3 code
in `owner`, `priority` and `conflict`. You only prepare migrations for those models.
None of these commands applies a branch's SQL to development or production.

<!-- workshop:run dev -->
```bash
cd /workspace
./tutorial parallel --yes
cd "/parallel/owner"
cat lib/Task.rakumod
red migration prepare add-owner
cd "/parallel/priority"
cat lib/Task.rakumod
red migration prepare add-priority
cd "/parallel/conflict"
cat lib/Task.rakumod
red migration prepare add-numeric-owner
```

**Expected:** all three new versions have the same predecessor. The main workspace
is still at step 2. The conflict variant intentionally adds `owner` with an incompatible
type. Inspect code and manifests in the parallel directories with nvim inside dev.

For a strictly linear exercise instead, `./tutorial next` from step 2 supplies both
compatible fields at once; prepare/apply that one migration. The remaining commands
below follow the parallel exercise, so do not take that alternative in this replay.

## 8. Integrate the generated code and serialize the migration fork

**Purpose:** `integrate` supplies the combined step-3 model and copies both prepared
histories into main. It leaves the migration fork unresolved for `red migration serialize`.
The main code stage and the database migration history remain distinct concepts.

<!-- workshop:run dev -->
```bash
cd /workspace
./tutorial integrate --yes
./tutorial status
# EXPECTED ERROR: both new migrations still have the same predecessor.
# Expect "Divergent or incomplete migration history" until serialize resolves the fork.
workshop expect-failure 'Divergent|incomplete' workshop compose exec -T dev red migration apply --test
base=$(workshop migration-id add-description)
owner=$(workshop migration-id add-owner)
priority=$(workshop migration-id add-priority)
red migration serialize --after="$base" --order="$owner,$priority" --check-connection=production
cat migrations/*/migration.rakuconf
red migration apply --test --driver=Pg -- raku -Ilib t/application.rakutest
red migration apply
workshop deploy v3
workshop check "Production runs release v3" test "$(curl -fsS http://prod:8080/version)" = v3
curl -fsS http://prod:8080/ | grep 'Production task'
workshop check "Both parallel fields exist in production" test "$(workshop compose exec -T db-prod psql -U postgres -d tasks -Atc "SELECT count(*) FROM information_schema.columns WHERE table_name='task' AND column_name IN ('owner','priority')")" = 2
workshop check "Production records all four applied migrations" test "$(workshop compose exec -T db-prod psql -U postgres -d tasks -Atc "SELECT count(*) FROM red_migrations WHERE state='applied'")" = 4
```

**Expected:** the owner migration retains its ID. Priority receives a new ID, points
to owner and records `replaces`. The already deployed prefix is unchanged. Production
has both fields and its original task. Never rewrite already executed versions;
include every shared database when supplying `--check-connection`.

## 9. Inspect an incompatible history in a separate directory

**Purpose:** the script creates an isolated history with both `owner` variants.
`serialize` must refuse the conflict and preserve all files. Production stays unchanged.

<!-- workshop:run dev -->
```bash
cd /workspace
./tutorial conflict --yes
cd "/parallel/conflict-demo"
find migrations -type f -exec sha256sum {} + | sort > /tmp/conflict-before
# EXPECTED ERROR: the two owner columns have incompatible types.
# Expect "Serialization conflict"; the wrapper requires failure and checks the message.
workshop expect-failure 'Serialization conflict' --stdin workshop compose exec -T -w "/parallel/conflict-demo" dev bash -se <<'SH'
base=$(workshop migration-id add-description)
owner=$(workshop migration-id add-owner)
other=$(workshop migration-id add-numeric-owner)
# EXPECTED ERROR: serialize must refuse this conflict without rewriting any files.
red migration serialize --after="$base" --order="$owner,$other"
SH
find migrations -type f -exec sha256sum {} + | sort > /tmp/conflict-after
workshop check "Conflicting serialization preserves all files" diff /tmp/conflict-before /tmp/conflict-after
workshop check "Conflict demonstration leaves production on v3" test "$(curl -fsS http://prod:8080/version)" = v3
# Leave the deliberately broken history before continuing with the final checks.
cd /workspace
```

**Expected:** an explicit conflict at the owner column and identical artifact checksums.
Agree on the desired model and replace unpublished conflicting work rather than editing
deployed history. The main workspace remains functional at step 3.
If you inspect `red migration status` or `red migration prepare` while still in
`/parallel/conflict-demo`, "Divergent or incomplete migration history" is expected:
that directory deliberately retains the unresolved fork. Return to `/workspace`
for the final checks; the conflict demonstration is not meant to be repaired.

## 10. Verify the final state

<!-- workshop:run dev -->
```bash
# REQUIRED: final checks run in the main project, not /parallel/conflict-demo.
cd /workspace
./tutorial status
red migration status
# No error is expected here: the main history is serialized and fully applied.
red migration prepare no-change | grep 'No schema changes'
workshop check "Reapplying migrations does no repeated work" test "$(red migration apply)" = 0
curl -fsS http://prod:8080/ | grep 'Production task'
```

**Expected:** code step 3, four applied migration versions, no extra migration and
zero repeated work. Restarting dev preserves the workspace and does not reset it.
The automated startup test checks this behavior. Inspect the model,
`.tutorial-state.json`, migration snapshots and both databases in another dev shell.

## Stopping and cleanup

Exit the dev shell. **On the host**, pause services while preserving code and databases:

```bash
docker compose --profile production stop
```

Use `docker compose start` to resume those same containers. A `restart` also keeps
the current code stage. Removing or recreating dev discards its project files;
the next container starts at step 1. Database volumes have a separate lifecycle.

To rebuild and restart the entire exercise from step 1 with empty databases
(this deletes the workshop's current code, migrations and database data):

```bash
docker compose --profile '*' down -v --remove-orphans
docker compose up -d --build --force-recreate --wait
docker compose exec dev bash
```

Old `workspace` and `checkouts` directories from earlier workshop versions are no
longer mounted or consulted. The repository's CI executes all marked commands in
isolation and cleans up only its own resources.
