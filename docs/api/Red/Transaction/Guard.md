class Red::Transaction::Guard
-----------------------------

Explicit lifetime control for a transaction or one of its savepoints.

### method scoped-driver

```raku
method scoped-driver() returns Mu
```

Internal driver used by ORM operations in this scope.

### method root

```raku
method root() returns Mu
```

Identity of the physical transaction shared by nested scopes.

### method retain

```raku
method retain() returns Mu
```

Reserves a participant before scheduling work that uses this scope.

### method release

```raku
method release() returns Mu
```

Releases one participant; the last rolls back an unfinished scope.

### method do

```raku
method do(
    &block
) returns Mu
```

Executes a block synchronously with its own participation.

### method start

```raku
method start(
    &block
) returns Mu
```

Reserves participation before scheduling a block; returns its Promise.

### method protect

```raku
method protect(
    &operation
) returns Mu
```

Internal synchronization boundary for statements and ORM access.

### method child

```raku
method child() returns Mu
```

Opens a child savepoint on the reserved session.

### method commit

```raku
method commit() returns Mu
```

Commits immediately, or releases this scope's savepoint.

### method rollback

```raku
method rollback() returns Mu
```

Rolls back once; safe to call unconditionally from a LEAVE phaser.

