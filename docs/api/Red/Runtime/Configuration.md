### sub runtime-context

```raku
sub runtime-context() returns Mu
```

Read project settings lazily, respecting Configuration's dynamic test overrides. Keep one context per thread and configuration reader; importing Red never evaluates a project file.

### sub runtime-settings

```raku
sub runtime-settings() returns Mu
```

Return configured settings without opening a database, or Nil when none are available.

### sub runtime-database

```raku
sub runtime-database() returns Mu
```

Resolve the default connection only on demand. Reuse factories' results per thread until the Configuration reader is replaced, including by set-config.

