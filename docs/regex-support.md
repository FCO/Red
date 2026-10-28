# Compiled regex coverage

This work is in progress. The target is Boolean regex predicates in Red queries,
using SQL execution wherever there is a supported translation, with explicit
errors elsewhere. This is not a promise to run arbitrary Raku, grammars or Match
objects inside a database.

```raku
use Red:api<2>;
CHECK red-compile;

# $*RED-DB selects the backend; .name must be textual.
User.^all.grep({ .name ~~ /:i ^ 'ana'/ });
my $prefix = 'a.';
User.^all.grep({ .name ~~ /^ $prefix/ }); # literal data, not regex source
```

The compiler requires the RakuAST frontend. Recent Rakudo installations already
use it by default; `RAKUDO_RAKUAST=1` selects it when needed. `use Red` exports `red-compile`;
`CHECK red-compile` enables query compilation for the current compilation unit.

## Engines

- **PostgreSQL:** a bound ARE pattern and the `~` operator.
- **MySQL 8:** a bound ICU pattern and `REGEXP_LIKE`, with explicit case-sensitive
  and dot/newline defaults. The external MySQL driver inherits this translation
  from `Red::Driver::CommonSQL`; no change to that distribution is required.
- **SQLite:** regex is disabled by default and raises a fatal compiler diagnostic.
  Enable it explicitly with `database "SQLite", :use-experimental-regex` (or
  `Red::Driver::SQLite.new(:use-experimental-regex)`). With this flag, literal-only search/prefix/suffix/exact patterns use built-in string
  operations; more general patterns use a bound Thompson automaton evaluated by
  recursive SQL CTEs. This requires neither an installed `regexp()` extension nor
  a Raku callback.
  `UNION` eliminates duplicate states, including empty cycles. Lookaround
  submachines share the input and preserve their start/end positions.
- Mock and cache wrappers are not separate database regex engines.

## Current matrix

The SQLite column below requires `:use-experimental-regex`. Without the flag,
all compiled regex predicates are rejected, including literal-only optimizations
and branches made unreachable by a constant condition. The check uses the query
driver, including explicit `.with($driver)` connections and nested cache wrappers.

| Feature | PostgreSQL | MySQL 8 | SQLite |
|---|---|---|---|
| Literal text, escaped characters, static quoted text and quoted word alternatives | Yes | Yes | Yes |
| Primitive numeric/Boolean subjects and constraint-only subsets | Yes | Yes | Yes |
| Literal scalar/array interpolation (`/$prefix/`, `/@names/`, `/"@names[]"/`) | Yes, bound data | Yes, bound data | Yes, bound data |
| Single `.match(/.../)` predicate, regex callable after scalar projection | Yes | Yes | Yes |
| Predicate postfix `if` / `unless` | Yes | Yes | Yes |
| Guarded `$0` and `$<name>` text comparisons | Yes, `regexp_match` | Explicit error | Explicit error |
| Guarded `$/` whole-match text comparisons | Yes, `regexp_match` | Yes, `REGEXP_SUBSTR` (8.0.17+) | Explicit error |
| Guarded `$/.defined` / `$/.Bool` | Yes, Boolean regex | Yes, Boolean regex | Yes, Boolean regex |
| Guarded scalar capture `.defined`, `.Bool` and Boolean `:exists` | Yes, `IS NOT NULL` | Explicit error | Explicit error |
| `^`, `$`, `^^`, `$$` | Yes | Yes | Yes |
| `<at(n)>`, `<.at(n)>`, `<?at(n)>`, `<!at(n)>` with a nonnegative literal integer | Yes, bounded lookbehind | Yes, bounded lookbehind | Yes, SQL submachine |
| `<(` and `)>` Match markers in Boolean predicates | Yes | Yes | Yes |
| `<<`, `>>`, `wb`, `ww` word assertions | Yes | Yes | Yes, ASCII word classification |
| `.`, `\d`, `\w`, `\s` and their negations | Yes | Yes | Yes, ASCII shorthand classes |
| `\h`, `\v`, `\n`, `\t` and their negations | Yes | Yes | Yes |
| Explicit character sets, union and subtraction | Yes | Yes | Yes |
| Static Unicode properties and scalar property values | Yes, generated ranges | Yes, generated ranges | Yes, generated ranges |
| `alpha`, `digit`, `alnum`, `lower`, `upper`, `xdigit`, `blank`, `cntrl`, `graph`, `print`, `punct`, `ws` | Yes | Yes | Yes; shorthand classification is ASCII |
| Bracket groups, positional/named groups and assertion aliases as predicates | Yes | Yes | Yes |
| `|`, `||` alternatives | Yes, native engine choices | Yes, native engine choices | Yes, Boolean language union |
| `&`, `&&` conjunction on regular patterns | Yes, automaton lowering | Yes, automaton lowering | Yes, automaton product |
| Greedy and frugal `?`, `*`, `+`, `**` | Yes | Yes | Yes, Boolean match only |
| Finite, open and endpoint-exclusive repetition bounds | Yes, larger bounds lowered | Yes | Yes, state limit |
| `%`, `%%` separators | Yes | Yes | Yes |
| Leading `:i`, `:!i`, `rx:i` | Yes | Yes | Yes, SQLite case folding |
| Scoped case changes | Explicit error | Yes | Yes |
| `:s`, `:!s`, `rx:s` significant whitespace | Yes | Yes | Yes |
| `<?name>` / `<!name>` for supported builtin or lexical regex names | Yes, engine restrictions | Yes | Yes, SQL submachines |
| `same`, `<?same>`, `<!same>` | Explicit error | Yes, native captures/lookaround | Yes, binary SQL comparison |
| Positive/negative lookahead and lookbehind | Yes, engine restrictions | Yes; bounded lookbehind | Yes |
| Nonrecursive lexical `regex` declarations, including direct `&name` matchers | Yes, subject to mode restrictions | Yes | Yes |
| Nonrecursive `token`/`rule` declarations | If no unsupported ratchet operation is needed | Yes | If no unsupported ratchet operation is needed |
| Ratcheted quantifiers, `:r` and builtin `ident` | Explicit error when atomic matching is needed | Yes, atomic matching | Explicit error when atomic matching is needed |
| Simple positional and named backreferences | Yes, native references ≤9; no `:i` | Yes, native limits | Explicit error |
| References inside a lookahead's own capture scope | Explicit error | Yes, native references | Explicit error |
| Local scalar references inside repeated capturing groups or lexical rules | Yes, native reference/mode limits | Yes | Explicit error |
| References to repeated capture lists | Explicit error | Explicit error | Explicit error |
| Code blocks, dynamic regex interpolation, arbitrary grammar execution | Explicit error | Explicit error | Explicit error |

Conjunction recognizes the same span in both operands. It is not translated as
independent Boolean searches over the column. Native patterns are generated by
state elimination, with a 128-state/64KiB lowering limit to avoid uncontrolled
pattern expansion. Captures/backreferences combined with conjunction remain an
explicit diagnostic. Raku's ordered-match choices can differ from a native
engine's choices even when their underlying regular languages agree.

Literal interpolation accepts defined primitive scalars and arrays/lists of
primitive values. It reads each query capture once, then escapes the resulting
text or literal alternatives. Empty alternative arrays match nothing; quoted
array interpolation uses Raku's explicit `@names[]` syntax. `Regex` objects,
executable interpolation and dynamic regex source (`/<$pattern>/`) are rejected.
Interpolated data inside inlined named rules are also rejected until their
original closure frame can be retained safely.

Named captures such as `$<name>=(a)` or `$<name>=[a+]` can participate in
Boolean predicates. Assertion aliases such as `<name=alpha>`, `<name=.alpha>`,
`<name=[ab]>` and aliases of lexical regex rules also bind a named capture.
Capturing subrule calls also bind their implicit names, for example
`<alpha> $<alpha>` or `<piece> $<piece>` for a lexical regex declaration.
Noncapturing `<.alpha>` does not bind a name. Multiple occurrences of the same
subrule name remain usable as predicates; references to their capture lists
are rejected explicitly. The builtin `ident` also requires atomic matching to
preserve its Raku token behavior, so it currently requires MySQL.
Named references use native capture references on PostgreSQL
and MySQL; SQLite rejects references explicitly. Alternative branches may bind
the same name. Repeated assignments to a name and array-valued captures remain
explicit errors rather than being collapsed into a native engine's last value.

Static Unicode predicates are resolved from the compiling Rakudo's Unicode data.
General categories, binary properties and literal values such as
`<:Script<Latin>>` are converted to scalar-value ranges. Executable predicates,
unknown properties/values and multi-value predicates are rejected. Static quoted
property arguments such as `<:Block('Basic Latin')>` and
`<:Script('Greek')>` are supported; interpolation and executable arguments remain errors.

Matching uses database normalization, character and collation behavior. In
particular, SQL characters are not Raku graphemes, SQLite's built-in `lower` and
`upper` are ASCII-only, and native case-insensitive matching can affect ranges
and classes differently from Raku. Queries return Boolean predicates; PostgreSQL
can read capture text within a predicate with an unambiguous regex source. No Match objects,
`.from`, `.to` or match-side effects are exposed.

Direct nullable columns and unsupported composite/custom subjects are rejected.
Primitive numeric subjects are cast using SQL's textual representation, which
can differ from Raku's numeric formatting. Boolean inputs use `True`/`False`
spelling; NULL-producing Boolean expressions remain NULL. No arbitrary Raku
stringifier is invoked. If an expression produces NULL, SQL's three-valued logic applies. Text containing NUL is outside
the supported domain. SQLite limits compilation to 4096 states and individual
repetition bounds to 1024; a smaller bound may exhaust the state budget when its
body is large. Large inputs or patterns can be expensive on any backend.

PostgreSQL bounds above 255 are decomposed into fixed and optional blocks, each
using native bounds no larger than 255. Fixed, finite, open, exclusive-endpoint
and frugal repetitions use this lowering. References to an earlier external
capture and references to a capture around the whole repetition are preserved.
Duplicating physically referenced captures inside a large repeat is rejected;
Raku capture-list references retain their existing explicit diagnostics. Lowering
has a 16-level nesting and 64K-character pattern budget. Database regex resource
limits still apply to the expanded expression.

Static position assertions use SQL character positions and preserve all required
preceding context. Only a nonnegative integer literal is accepted; arbitrary
argument expressions, captured positions and user-defined `at` overrides are
rejected without execution. Native lookbehind and SQLite automaton resource
limits apply. Match markers `<(` and `)>` preserve the required surrounding
pattern while only the predicate's truth value is returned. Captures containing
these markers cannot currently be referenced: their Match boundary behavior is
an explicit diagnostic rather than a substituted native capture.

Named lookaheads resolve supported builtin names and pure lexical regex rules.
Lexical overrides are respected, including overrides of builtin anchor names.
The `same` assertion compares the adjacent SQL characters exactly even under
`:i`; its negation succeeds at input boundaries. MySQL uses internal native
capture slots whose numbers remain separate from user capture identities.
SQLite uses a binary comparison. PostgreSQL currently rejects `same`, and MySQL
rejects `same` combined with conjunction until capture-aware automaton lowering
is available. These limitations never enable row filtering in Raku.

Capture references remain case-sensitive in Raku even under `:i`. MySQL
locally disables case folding for the reference while retaining the surrounding
pattern's case mode. PostgreSQL rejects references under `:i` until a correct
scoped-case lowering is available.

MySQL can use positional and named capture references inside positive/negative
lookaheads, including lookaheads of pure lexical regex rules. Each assertion has
its own Raku capture scope: local captures do not become visible to the outer
pattern, and outer captures do not become assertion-local slots. Native physical
capture numbering remains consistent across nested assertions and outer groups.
PostgreSQL rejects backreferences inside lookaround; SQLite rejects capture
references. Backreference-dependent lookbehind widths and capture-list references
remain explicit diagnostics.

Capture scopes remain distinct when their containing operation repeats. A local
reference in `((a) $0)+` or a repeated lexical rule still refers to the scalar
capture in that invocation; a reference to the repeated outer group remains a
capture-list reference and is rejected. The same isolation applies to local
references in lookaheads inside a consuming repeated group (MySQL only).
Parenthesized named captures introduce a scope; bracketed assignments share the
outer scope. Unbounded zero-width repetition containing references is rejected
explicitly; finite repetitions keep the normal backend reference policy.

## Guarded capture text

```raku
use Red;
CHECK red-compile;
my $*RED-DB = database "Pg";

# $0 is the first parenthesized capture.
Bla.^all.grep({ $0 eq "bla ble" if .ble ~~ /^ ('bla ' \w+)/ });
# $/ reads the whole matched text, including when the regex has no groups.
Bla.^all.grep({ $/ eq "bla ble" if .ble ~~ /^ 'bla ' \w+/ });
```

Regex whitespace is normally insignificant: quote a space or use `:s` when it
must match input. For example, `/^bla \w+/` is equivalent to `/^bla\w+/`
and does not match `"bla ble"`. `/^ 'bla ' \w+/` matches a literal space;
`/:s ^bla \w+/` uses word-separating whitespace instead. A regex without
parentheses does not define `$0`.

PostgreSQL supports scalar text reads using `$0`, `$1`, literal named captures
such as `$<word>`, `$/`, `.Str` and `~` string coercion in text comparisons.
Explicit coercion also permits SQL text method chains such as `$0.Str.lc`,
`$<word>.Str.uc`, `$/.Str.substr(1, 2)` and `(~$/).lc`. These use the
existing native text operations and retain database Unicode/collation behavior.
Raw Match method calls remain unsupported; extracting scalar text still requires
PostgreSQL, while whole text is also available on MySQL.
Regex conditions bind the capture source for postfix `if`/`unless`, full `if`,
ternary predicates and logical `&&` / `||` expressions. The compiler follows
short-circuit branches and accepts a read only when its match source is
unambiguous. For example, `.text ~~ /(a)/ && $0 eq "a"` reads the first group
from that match. A successful OR with distinct possible match sources is rejected. Reads use `regexp_match` over the original SQL
subject, so surrounding context, lookaround and aliases are preserved. Captured
pattern data are still bound once; captures never come from the caller's Raku
match state. Optional or absent groups produce SQL NULL, while an empty matched
group produces an empty string. SQL NULL comparison semantics apply.

Capture lists, lookup adverbs other than Boolean `:exists`, nested Match/container APIs, unguarded reads and ambiguous
short-circuit match sources are rejected explicitly. Whole-match reads involving
`<(` / `)>` markers are not implemented. Adding the outer whole-match capture
also consumes a native group number for PostgreSQL backreference limits.

MySQL 8.0.17+ supports whole-match `$/` reads with `REGEXP_SUBSTR` on the original
subject and first occurrence. Capturing groups do not change the returned span.
The result is converted to UTF-8 text with `utf8mb4_0900_bin` so text comparisons
preserve case and trailing spaces without becoming a binary-string regex input.
This collation was introduced in [MySQL 8.0.17](https://dev.mysql.com/doc/relnotes/mysql/8.0/en/news-8-0-17.html).
MySQL still rejects scalar group reads; SQLite rejects all capture text reads.
Match boundary markers remain explicit errors on both text extraction backends.

## Capture character counts

`$0.chars`, `$<name>.chars` and `$/.chars` count extracted text using native
SQL character units. `.Str.chars` and `(~$/).chars` are also supported.
Whole text counts work on PostgreSQL and MySQL; scalar group counts require
PostgreSQL. SQLite retains its explicit text extraction error.
Empty or absent scalar captures and failed whole matches count as zero.
Capture lists remain unsupported. Native characters can differ from Raku NFG
graphemes, especially for combining sequences and multi-codepoint emoji.

## Capture presence

`$/.defined` and `$/.Bool` after a regex with an unambiguous source use the existing
Boolean match predicate and are available on all matching backends. SQLite still
requires its experimental flag. PostgreSQL also supports scalar `$0.defined`,
`$0.Bool`, `$0:exists`, `$<name>.defined` and `$<name>:exists` in Boolean contexts.
A present empty capture is true; an absent/optional unmatched group is false.
Explicit `so`, `!` and `not` on scalar captures use this same presence test.
Negated presence checks and `unless` use the same isolated match source.

Scalar presence uses `IS NOT NULL` over capture text. It does not stringify a
Boolean or invoke Raku Match methods. MySQL and SQLite retain explicit errors
for scalar capture presence; capture-list presence remains unsupported.
Lookup operations such as `:delete`, unguarded reads and presence checks used as
text values are rejected rather than given different lookup/coercion semantics.

## Diagnostics and isolation

An unsupported compiled regex throws `X::Red::Compiler::Unsupported` with
`fatal == True`. Red does not run the rejected callback symbolically or fetch the
rows for an in-memory regex fallback, even with `$*RED-FALLBACK = True`. Other
unsupported query constructs keep their existing fallback policy. Instrumented
calls on ordinary Raku collections still dispatch to Raku without Red metadata.

Literal pattern data are bound as parameters. SQL state identifiers, transition
numbers and generated Unicode range endpoints are compiler-owned values.
Neither interpolated Raku source nor arbitrary raw SQL is evaluated.

## Remaining feature work

These are explicit diagnostics, not silently approximated support:

- References to duplicate/repeated subrule names, repeated explicit named capture
  assignments and nested Match/capture container APIs.
- Capture-list backreferences, references crossing lookaround scope or Match markers,
  and unbounded zero-width repetition containing capture references.
- Atomic/ratcheted semantics on engines without implemented atomic lowering,
  commits/cuts, and further token/rule combinations.
- Capture references combined with conjunction and larger conjunctions exceeding
  the explicit lowering resource limits.
- Regex variables as executable matchers, dynamic regex source, substitutions,
  match-result APIs and additional match-call adverbs.
- Literal interpolation through an inlined rule's original closure frame.
- Recursive rules/grammars, signatures with arguments, actions, phasers and code.
- Additional contextual assertions, properties with executable predicates and
  properties involving multiple simultaneous values.
- Broader PostgreSQL mode lowering and SQLite nonregular capture behavior.

## Validation

`t/107-compiled-regex.rakutest` covers compiler integration and the original
PostgreSQL feature. `t/108-regex-dialects.rakutest` compares database results with
Raku on a shared ASCII corpus, checks Unicode scalar properties including
supplementary-plane characters, exercises scopes/backreferences, atomic matching, conjunction, literal data binding and verifies
compiled ORM predicates, projection rebinding and explicit errors without
fallback. `t/109-regex-no-fallback.rakutest` checks rejected callbacks against a
model whose table does not exist, proving rejection occurs before a row fetch.
`t/110-regex-repetitions.rakutest` compares large repetition boundaries and
external capture references with Raku, including the PostgreSQL bound lowering.
`t/111-regex-positions.rakutest` checks static position assertions, negations,
Match markers, surrounding context and rejection of executable argument values.
`t/112-regex-named-assertions.rakutest` checks named lookaheads, lexical overrides,
exact adjacent-character assertions, Unicode scalars and internal capture numbering.
`t/113-regex-assertion-captures.rakutest` checks assertion-local capture references,
positive/negative and nested lookaheads, scope isolation and backend diagnostics.
`t/114-regex-repeated-scopes.rakutest` checks local references through repeated
capture scopes, lexical rules, lookaheads and literal binding, while keeping
capture-list references explicit errors. Static Regex objects provide its Raku oracle.
`t/115-regex-capture-reads.rakutest` covers predicate modifiers, guarded capture
text, absent/empty groups, alternatives, aliases, literal binding, whole-match
numbering and explicit unsupported cases.
`t/116-regex-capture-presence.rakutest` checks whole-match and scalar group
presence, absent/empty groups, negations, `unless` and explicit lookup diagnostics.
`t/117-regex-whole-text.rakutest` checks first whole-match text, groups,
lookaround context, case/trailing spaces, empty matches, Unicode and literal binding.
`t/118-regex-logical-captures.rakutest` checks logical capture flow, nested guards,
failed matches, equivalent sources and explicit ambiguity diagnostics.
`t/119-regex-cache-driver.rakutest` checks SQLite opt-in enforcement through
cache wrappers, nested wrappers and reused compiled callbacks.
`t/120-regex-property-literals.rakutest` compares static parenthesized Unicode
properties with Raku and checks nonliteral argument diagnostics.
`t/121-regex-text-methods.rakutest` checks explicit string coercion, chained
SQL text operations and backend extraction restrictions.
`t/122-regex-capture-chars.rakutest` checks native capture lengths, Unicode scalar
characters, empty/absent groups and direct/interpreted factory agreement.
Run these tests with the desired `RED_DATABASE`; it uses SQLite by default.

## Engine references

- [PostgreSQL ARE matching](https://www.postgresql.org/docs/current/functions-matching.html)
- [MySQL regular expression functions](https://dev.mysql.com/doc/refman/8.4/en/regexp.html)
- [ICU regex syntax and atomic groups](https://unicode-org.github.io/icu/userguide/strings/regexp.html)
- [SQLite expressions and the optional regexp function](https://www.sqlite.org/lang_expr.html)
- [SQLite recursive CTEs](https://www.sqlite.org/lang_with.html)
