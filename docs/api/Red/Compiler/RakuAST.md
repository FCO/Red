module Red::Compiler::RakuAST
-----------------------------

Optional CHECK-time translation of query callbacks. No RakuAST types are resolved while loading this module on the legacy frontend.

### sub red-compile

```raku
sub red-compile(
    $cu = Code.new,
    :&report,
    Bool :$warn
) returns Mu
```

Translate supported callbacks in the caller's current compilation unit.

