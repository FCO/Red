# Optional RakuAST query compiler

The optional compiler translates supported query callbacks during `CHECK`.
Enable the RakuAST frontend and explicitly opt in for each compilation unit:

```raku
use Red:api<2>;
use Red::Compiler::RakuAST;
CHECK red-compile;

my $minimum = 10;
my $query = Product.^all
    .map({ .price + 2 })
    .grep({ $_ > $minimum })
    .map({ "price: $_" });
```

Run the program with `RAKUDO_RAKUAST=1 raku -Ilib program.raku`.
This integration is experimental and tested with Rakudo 2026.09. Loading Red
without opting in keeps the existing frontend and callback behavior.

The compiler recognizes literal blocks, pointy blocks (including tuple
parameters), placeholder parameters, and single-Whatever expressions passed to `map`, `grep`, `first`,
and `sort`. Supported expressions include model columns, constant indexes and
Hash keys, dynamic JSON indexes and key existence, scalar and container projections, arithmetic, comparisons, string
concatenation and interpolation, complete conditionals, and `defined`,
`contains`, `elems`, `starts-with`, `ends-with`, `substr`, `index`, `lc`, `uc`,
and `cast`. Membership predicates accept literal word lists, captured arrays and
subqueries. Hash projections accept both fat arrows and colonpairs. Boolean operators are translated in predicates only.
Comparisons retain the resolved Red operator, including its numeric or textual
coercions and SQL casts.

Templates bind against the current projection, so SQL aliases and SELECT
boundaries remain the responsibility of the existing query planner. Scalar
lexical captures are read when the query is constructed and retained if the
planner needs to bind the template against another SELECT layer.

During CHECK the compiler specializes factories that construct `Red::AST` nodes
directly, along with the required validators. Runtime query construction invokes
these factories rather than interpreting the expression plan. Factories are
shared across calls; captured values and SQL subjects remain private to each
query. CHECK time is separate from runtime query construction and execution.

Map templates also record column and JSON assignments, arithmetic compound
assignments (`+=`, `-=`, `*=`, `/=`, `%=` and `~=`), increments, decrements and
JSON deletion. These effects use the existing update pipeline and are persisted
with `.save`. Updates are buffered until the template evaluates successfully.
Simple untyped scalar locals and sequential statements can be compiled too.
Compound assignment to a projected scalar or a local variable changes the
expression used by later statements; it does not turn that projection into a
database update. Postfix increment/decrement retains its original return value.

Expressions independent of the query element, including constructors and function
calls, can be bound as runtime captures. Their code runs during query construction,
never during CHECK. Ordinary native receivers still execute their original callback.

An unsupported callback is left on the existing symbolic evaluation path,
including its existing fallback policy. Named callbacks, arbitrary functions of
the query element, loops, phasers, constrained signatures, custom operators and
conditional updates are not compiled. Unsupported syntax is rejected as a complete
callback before any updates are submitted.
Translation never executes the original callback during CHECK.

Instrumented calls check their receiver at runtime. A `ResultSeq` receives an
internal template alongside the original callback. Other receivers receive the
original arguments, preserving native dispatch, adverbs, and writable results.
The compiler does not add SQL semantics to ordinary Arrays or Seqs.

For compilation diagnostics, pass a reporting callback:

```raku
CHECK red-compile(:report(-> :$method, :$source, :$status, :$reason {
    note "$method: $status ($reason)";
}));
```

Reports distinguish translated callbacks from unsupported syntax and include the
original callback source. A compiled template can still be inapplicable to a
particular runtime projection. To observe successful template evaluation, set
`$*RED-COMPILER-REPORT` to a callable; it receives `:status<used>`, `:plan`, and
`:engine<direct>` for generated factories, or `:status<fallback>` and `:reason`.
Manually constructed templates without a factory report `:engine<interpreted>`.
This is useful for tests that must distinguish compilation from symbolic fallback.

To measure factory runtime separately from CHECK, database execution, and the
query planner, run `raku -Ilib tools/benchmark-compiler.raku`. The benchmark emits
JSON samples comparing interpreted and direct factories in the same process,
with warmup and alternating measurement order. Factory specialization happens
before timing. `--iterations=1000` and `--rounds=7` control the sample size.
These measurements isolate binding and AST construction; they do not represent
the speedup of an entire query.

## Runtime query-plan cache

A ResultSeq automatically reuses its SQL plan when its state can be fingerprinted
safely. Opaque mutable values bypass caching. The database
is still queried each time, using a fresh statement and cursor. Changes to the
query, driver, pagination or SQL metadata select a different plan. Diagnostic
comments are attached for the current execution. `.cache` continues to materialize
query results; it is separate from this plan cache.

The optional compiler also shares predicate trees for direct comparisons between
a model field and one captured scalar (`Int`, `Str`, `Rat` or `Num`). Each query
reads its capture once during construction and retains that private snapshot:

```raku
sub expensive($minimum) {
    Product.^all.grep({ .price > $minimum })
}
my $first = expensive(10);
my $second = expensive(20);
```

After warming up, these calls reuse the predicate factory output and SQL while
keeping their parameters independent. Other callbacks, mutable captures, NULL
captures and updates retain their existing factory/fallback behavior. Comparisons
requiring scalar coercion also use ordinary factories. Caches are bounded to 128
entries, synchronized, and live only in the current process.
Prepared statements are not shared between connections or iterators. The SELECT
wrapper and current metadata are still inspected; reusing a predicate does not
eliminate every AST allocation. Warm-up has a cost, and for small predicates the
construction cost can remain similar. Plan reuse still hydrates every row, so end-to-end
gains depend on how much of the workload is spent translating SQL.
Drivers based on CommonSQL enable plan caching; other drivers retain their
existing prepare path unless they opt in with `supports-query-plans`.

`$*RED-COMPILER-REPORT` additionally receives `filter-hit`, `filter-miss`,
`plan-hit`, `plan-miss` and `plan-fallback` events. Plan fallback includes a reason.
For comparisons, `my $*RED-QUERY-PLAN-CACHE = False` disables both runtime caches.
Run `raku -Ilib tools/benchmark-query-plans.raku` to compare construction,
translation/planning (dry run), and execution with caching enabled and disabled.
The benchmark alternates variants and reports cold-plan and warmed measurements
in microseconds per operation as JSON. Module compilation and database setup are
excluded. A separate `prototype-samples` series compares first specialization
with the saved symbolic AST against the runtime factory, using empty predicate
caches in both variants.
For direct field/scalar comparisons, CHECK also constructs a `Red::AST` prototype
with symbolic field and parameter slots. That object is embedded in the template
and saved with the module in `.precomp`. Its first use resolves the model column,
alias and parameter type from the prototype; later calls reuse the resolved
predicate. Runtime captures, connections, query objects and SQL plans are never
saved in the module. Other expressions continue to use CHECK-generated factories;
this does not eliminate the runtime SELECT envelope or every AST allocation.

## Measuring model access and cache bookkeeping

`raku -Ilib tools/benchmark-model-access.raku` measures loading and reading models,
repeated field reads, and field writes without saving. It uses an in-memory SQLite
database, checks the results, warms each task, alternates task order between rounds,
and emits JSON samples. Use `--rows`, `--load-iterations`, `--access-iterations` and
`--rounds` to control the workload. Database setup and module compilation are excluded.

`raku -Ilib tools/benchmark-query-cache.raku` isolates cache lookup costs with 1, 16
and 128 entries. It measures both a warmed working set and continual eviction, checks
builder counts, and reports microseconds per lookup. `--iterations` and `--rounds`
control the sample size. These cache and field-access measurements isolate individual
operations; use the query-plan benchmark to evaluate their effect on SQL workloads.
