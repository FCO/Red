Red::Migration::Test
--------------------

### sub migration-ok

```raku
sub migration-ok(
    IO(Any) $configuration = "red.rakuconf",
    |options
) returns Mu
```

Add a Test subtest that validates the configured history on disposable databases. Forward options to Manager.test and report execution or schema failures as failed assertions.

