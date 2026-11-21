# Contributing

Your pull requests to [Red](https://github.com/FCO/Red) are very welcome.

Your contributions here will be credited in the Red README.md file. Your name from the commit log will be used. If you'd like to be credited under a different name, please add it to the local CREDITS file (or ask someone to do it for you until you have commit privileges).

If you have any questions regarding contributing to this project, please ask in the #perl6 IRC channel.

## Squashathon

The list of issues for the squashathon can be found here: https://github.com/FCO/Red/labels/Documentation

## Documentation examples

Run `raku tools/check-doc-examples.raku` from the repository root. The Raku runner
checks the documented source against the scenario fixtures in
`tools/doc-examples.json` and tests behavior in temporary projects. Update the
source guard and the corresponding assertions together when changing an example.
Reports are written to `test-results/doc-examples`. Use `--match=NAME` to select a
scenario and `--inventory-only` to check source guards without executing examples.

External database scenarios require explicitly enabled disposable environments
(`RED_DOC_PG`, `RED_DOC_MYSQL`, or `RED_DOC_DUCKDB`). Installation, publishing and
placeholder shell examples receive syntax checks. The migration workshop has its
own end-to-end runner: `raku examples/migrations/test-walkthrough.raku`.
