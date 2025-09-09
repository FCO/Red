# Red ORM Development Instructions

Red is a Raku ORM (Object-Relational Mapping) library that provides a powerful interface for database operations. Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

### Prerequisites and Setup
- Install Raku >= 2022.07: `sudo apt install -y rakudo`
- Install zef package manager if not available:
  ```bash
  cd /tmp && git clone https://github.com/ugexe/zef.git && cd zef && raku -I. bin/zef install .
  export PATH="/home/runner/.raku/bin:$PATH"  # Add to PATH
  ```
- Install project dependencies: `zef install --/test --test-depends --deps-only .`
- NEVER CANCEL: Dependency installation takes 5-10 minutes. Set timeout to 15+ minutes.

### Building and Validation
- **NO TRADITIONAL BUILD STEP**: Raku is interpreted, no compilation required
- Quick syntax check (lint): `raku -Ilib -c lib/Red.rakumod` (and for any changed files)
- Always include `-Ilib` flag when running Raku with Red modules locally
- Build time: Syntax checking takes seconds, dependencies take 5-10 minutes

### Testing
- Install test dependencies: `zef install --/test App::Prove6` (if not already installed)
- Run full test suite: `prove6 -lj8 t` 
- NEVER CANCEL: Full test suite takes 2-3 minutes. Set timeout to 10+ minutes.
- Run single test: `prove6 -lv t/filename.rakutest` (replace filename as needed)
- Test coverage: 86 test files, 1117+ tests total
- Database setup: Tests use temporary SQLite by default (no setup required)

### Examples and Manual Testing
- Run examples: `cd examples/blog && raku -I../../lib index.raku`
- Available examples: blog, blog2, ticket, xmas, alive, cqrs
- Examples demonstrate ORM functionality and serve as integration tests
- Always test examples after making ORM changes to validate functionality
- Examples use SQLite by default and create tables automatically
- Test multiple examples: `cd examples/ticket && raku -I../../lib index.raku`

### Documentation
- Generate docs: `make docs` or `raku -Ilib tools/make-docs.raku`
- NEVER CANCEL: Documentation generation takes 60-90 seconds. Set timeout to 5+ minutes.
- Clean docs: `make clean-docs` 
- NOTE: Doc generation may show Pod::To::Markdown errors but still produces output
- Generated docs appear in docs/ directory

## Database Configuration

### SQLite (Default)
- No setup required - SQLite used automatically for tests and examples
- Temporary databases created as needed
- Use for development and testing

### PostgreSQL
- Install: `sudo apt install -y postgresql postgresql-client libpq-dev`
- Install Raku driver: `zef install DB::Pg`
- Set environment: `export RED_DATABASE="Pg host=localhost port=5432 dbname=red_test user=postgres password=postgres"`
- Required for PostgreSQL-specific tests in CI

## Development Workflow

### Making Changes
- Always run syntax check: `raku -Ilib -c lib/ModifiedFile.rakumod`
- Run relevant tests: `prove6 -lv t/related-test.rakutest`
- Test examples that use modified functionality
- Run full test suite before submitting: `prove6 -lj8 t`

### Code Style and Standards
- Use 4-space indentation, no tabs
- Trim trailing whitespace
- Keep lines ~100 characters or less
- One statement per line
- Types: CamelCase; methods/attributes: kebab-case
- Add type constraints: Int, Str, Bool, DateTime, etc.
- Use `is rw` only when mutation required

### CI Validation
- Replicate CI locally using: `prove6 -lj8 t` (matches .github/workflows/matrix.yaml)
- PostgreSQL tests: Set RED_DATABASE environment variable
- NEVER CANCEL: CI tests may take 5-10 minutes. Always wait for completion.

## Common Tasks

### Repository Structure
```
/
├── lib/                 # Main Red ORM source code
├── t/                   # Test files (.rakutest extension)
├── examples/            # Working example applications
├── tools/               # Utility scripts (docs generation)
├── .github/workflows/   # CI configuration
├── META6.json          # Package metadata and dependencies
└── README.md           # Project documentation
```

### Key Files
- `lib/Red.rakumod` - Main ORM module
- `META6.json` - Project metadata and dependencies
- `t/*.rakutest` - Test files (86 total)
- `.github/workflows/matrix.yaml` - CI configuration

### Quick Commands Reference
```bash
# Setup (run once)
zef install --/test --test-depends --deps-only .

# Syntax check
raku -Ilib -c lib/Red.rakumod

# Single test
prove6 -lv t/01-tdd.rakutest

# Full test suite (NEVER CANCEL - 2-3 minutes)
prove6 -lj8 t

# Run example
cd examples/blog && raku -I../../lib index.raku

# Generate docs (NEVER CANCEL - 60-90 seconds)
make docs
```

## Validation Scenarios

### After Making Changes
1. **Syntax Check**: Run `raku -Ilib -c` on modified files
2. **Unit Tests**: Run related test files with `prove6 -lv t/testfile.rakutest`
3. **Integration Test**: Run relevant examples to test functionality
4. **Full Validation**: Run complete test suite with `prove6 -lj8 t`
5. **Documentation**: Regenerate docs if public APIs changed

### Example Validation Flow
```bash
# After modifying lib/Red/Model.rakumod
raku -Ilib -c lib/Red/Model.rakumod
prove6 -lv t/01-tdd.rakutest t/23-metamodel-model.rakutest
cd examples/blog && raku -I../../lib index.raku
cd ../ticket && raku -I../../lib index.raku  # Test multiple examples
prove6 -lj8 t  # Full suite
```

## Critical Timing Information

- **NEVER CANCEL** any of these operations:
  - Dependency installation: 5-10 minutes (timeout: 15+ minutes)
  - Full test suite: 2-3 minutes (timeout: 10+ minutes)  
  - Documentation generation: 60-90 seconds (timeout: 5+ minutes)
  - CI replication may take 5-10 minutes total

## Troubleshooting

### Common Issues
- **"Could not find Red::Module"**: Use `-Ilib` flag with raku commands
- **zef not found**: Install manually from GitHub (see Prerequisites)
- **Test failures**: Check if RED_DATABASE is set incorrectly for SQLite tests
- **Doc generation errors**: Pod::To::Markdown missing but output still generated

### Dependencies
- Core: DBIish, DB::Pg, UUID, JSON::Fast
- Testing: Test::META, App::RaCoCo, App::Prove6
- Docs: File::Find, Pod::To::Markdown (optional)

Always wait for operations to complete and avoid canceling long-running commands. The ORM handles complex database operations that require time to execute properly.