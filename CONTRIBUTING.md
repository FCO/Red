# Contributing

Your pull requests to [Red](https://github.com/FCO/Red) are very welcome.

Your contributions here will be credited in the Red README.md file. Your name from the commit log will be used. If you'd like to be credited under a different name, please add it to the local CREDITS file (or ask someone to do it for you until you have commit privileges).

If you have any questions regarding contributing to this project, please ask in the #perl6 IRC channel.

## Optional compiler tests

Run the existing test suite with whichever of Rakupp and Mutsu are on your `PATH`:

```sh
bash tools/test-alternative-compilers.sh
bash tools/test-alternative-compilers.sh --compiler mutsu t/35-create.rakutest
```

Test paths are relative to the checkout. Install dependencies separately for each
compiler before running; the script does not install anything. It uses the Perl TAP
harness `prove`, prints a result for each compiler, and saves diagnostics in a temporary
directory reported at startup. Set `ALT_COMPILER_LOG_DIR` to choose that directory.

Local runs return status `0` even when tests fail or tools are missing. Add `--strict`
to return a failure status instead. The experimental GitHub Actions jobs use this
mode with `continue-on-error: true`, so failures remain visible without failing the
workflow. Existing Rakudo jobs remain required.

## Squashathon

The list of issues for the squashathon can be found here: https://github.com/FCO/Red/labels/Documentation
