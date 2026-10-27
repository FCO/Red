#!/usr/bin/env bash

# Informational locally; --strict preserves failures for optional CI jobs.
strict=0
failed=0
compilers=(rakupp mutsu)
tests=()

finish() {
    if [ "$strict" -eq 1 ]; then
        exit "$failed"
    fi
    exit 0
}

usage() {
    printf '%s\n' \
        'Usage: bash tools/test-alternative-compilers.sh [--strict]' \
        '       [--compiler rakupp|mutsu] [--] [test files or directories...]' \
        '' \
        'Defaults: installed alternative compilers, all of t/, exit status 0.' \
        '--strict returns 1 on failure, missing tools, or a missing selected compiler.' \
        'Dependencies must already be installed for each compiler.' \
        'ALT_COMPILER_DEPENDENCIES optionally names a JSON list of source directories.' \
        'ALT_COMPILER_TEST_TIMEOUT sets seconds per test (default 30).' \
        'ALT_COMPILER_JOBS sets parallel test processes (default 4).' \
        'ALT_COMPILER_LOG_DIR optionally selects the log directory.'
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --strict) strict=1; shift ;;
        --compiler)
            case "${2:-}" in
                rakupp|mutsu) compilers=("$2"); shift 2 ;;
                *) printf '%s\n' 'Expected --compiler rakupp or --compiler mutsu.'
                   failed=1; finish ;;
            esac
            ;;
        --help|-h) usage; exit 0 ;;
        --) shift; tests+=("$@"); break ;;
        -*) usage; failed=1; finish ;;
        *) tests+=("$1"); shift ;;
    esac
done

if [ "${#tests[@]}" -eq 0 ]; then
    tests=(t/)
fi

# Test paths are relative to the checkout, regardless of the caller's directory.
if ! cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."; then
    printf '%s\n' 'Could not locate the Red checkout.'
    failed=1
    finish
fi

if [ -n "${ALT_COMPILER_LOG_DIR:-}" ]; then
    log_dir=$ALT_COMPILER_LOG_DIR
    if ! mkdir -p -- "$log_dir"; then
        printf '%s\n' 'Could not create the log directory.'
        failed=1
        finish
    fi
else
    if ! log_dir=$(mktemp -d "${TMPDIR:-/tmp}/red-alternative-compilers.XXXXXX"); then
        printf '%s\n' 'Could not create a temporary log directory.'
        failed=1
        finish
    fi
fi

printf 'Logs: %s\n' "$log_dir"
if ! command -v prove >/dev/null 2>&1; then
    printf '%s\n' 'UNAVAILABLE: TAP harness prove is not installed; no tests ran.'
    failed=1
    finish
fi
if ! command -v python3 >/dev/null 2>&1; then
    printf '%s\n' 'UNAVAILABLE: python3 is required for per-file timeouts; no tests ran.'
    failed=1
    finish
fi

ran=0
for compiler in "${compilers[@]}"; do
    if ! command -v "$compiler" >/dev/null 2>&1; then
        printf '%s: SKIPPED (not installed)\n' "$compiler"
        # In strict mode, every compiler in the requested set is required.
        failed=1
        continue
    fi
    ran=$((ran + 1))
    log_file="$log_dir/$compiler.log"
    printf '%s: running tests...\n' "$compiler"
    # Keep compiler diagnostics out of the terminal, but retain them in the log.
    # --norc prevents a local .proverc from overriding the chosen executor.
    if (
        printf 'Compiler: %s\n' "$(command -v "$compiler")"
        python3 tools/alternative-compiler-exec.py "$compiler" -e 'say $*RAKU.compiler'
        prove --norc --recurse --ext .rakutest --verbose \
            --jobs "${ALT_COMPILER_JOBS:-4}" \
            --exec "python3 tools/alternative-compiler-exec.py $compiler" "${tests[@]}"
    ) >"$log_file" 2>&1; then
        printf '%s: PASS (%s)\n' "$compiler" "$log_file"
    else
        status=$?
        printf '%s: FAIL (exit %s; see %s)\n' "$compiler" "$status" "$log_file"
        failed=1
    fi
done

if [ "$ran" -eq 0 ]; then
    printf '%s\n' 'No alternative compilers were available; no tests ran.'
fi
if [ "$strict" -eq 0 ]; then
    printf '%s\n' 'Informational run: exit status 0, including when tests fail.'
fi
finish
