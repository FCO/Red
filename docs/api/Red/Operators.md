Red::Operators
--------------

### multi sub prefix:<-->

```raku
multi sub prefix:<-->(
    Red::Column $a
) returns Mu
```

--X

### multi sub prefix:<++>

```raku
multi sub prefix:<++>(
    Red::Column $a
) returns Mu
```

++X

### multi sub postfix:<-->

```raku
multi sub postfix:<-->(
    Red::Column $a
) returns Mu
```

X--

### multi sub postfix:<++>

```raku
multi sub postfix:<++>(
    Red::AST $a
) returns Mu
```

X++

### multi sub prefix:<->

```raku
multi sub prefix:<->(
    Red::AST $a
) returns Mu
```

-X

### multi sub prefix:<+>

```raku
multi sub prefix:<+>(
    Red::AST $a
) returns Mu
```

+X

### multi sub infix:<+>

```raku
multi sub infix:<+>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X + Y

### multi sub infix:<+>

```raku
multi sub infix:<+>(
    Red::AST $a,
    Numeric(Any) $b
) returns Mu
```

X + Y # Where Y is castable to Numeric

### multi sub infix:<+>

```raku
multi sub infix:<+>(
    Numeric(Any) $a,
    Red::AST $b
) returns Mu
```

X + Y # Where X is castable to Numeric

### multi sub infix:<->

```raku
multi sub infix:<->(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X - Y

### multi sub infix:<->

```raku
multi sub infix:<->(
    Red::AST $a,
    Numeric(Any) $b
) returns Mu
```

X - Y # Where Y is castable to Numeric

### multi sub infix:<->

```raku
multi sub infix:<->(
    Numeric(Any) $a,
    Red::AST $b
) returns Mu
```

X - Y # Where X is castable to Numeric

### multi sub infix:<*>

```raku
multi sub infix:<*>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X * Y

### multi sub infix:<*>

```raku
multi sub infix:<*>(
    Red::AST $a,
    Numeric(Any) $b
) returns Mu
```

X * Y # Where Y is castable to Numeric

### multi sub infix:<*>

```raku
multi sub infix:<*>(
    Numeric(Any) $a,
    Red::AST $b
) returns Mu
```

X * Y

### multi sub infix:</>

```raku
multi sub infix:</>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X / Y

### multi sub infix:</>

```raku
multi sub infix:</>(
    Red::AST $a,
    Numeric(Any) $b
) returns Mu
```

X / Y # Where Y is castable to Numeric and read only

### multi sub infix:</>

```raku
multi sub infix:</>(
    Numeric(Any) $a,
    Red::AST $b
) returns Mu
```

X / Y # Where X is castable to Numeric and read only

### multi sub infix:</>

```raku
multi sub infix:</>(
    Red::AST $a,
    Numeric(Any) $b is rw
) returns Mu
```

X / Y # Where Y is castable to Numeric and writable

### multi sub infix:</>

```raku
multi sub infix:</>(
    Numeric(Any) $a is rw,
    Red::AST $b
) returns Mu
```

X / Y # Where X is castable to Numeric and writable

### multi sub infix:<div>

```raku
multi sub infix:<div>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X div Y

### multi sub infix:<div>

```raku
multi sub infix:<div>(
    Red::AST $a,
    Numeric(Any) $b
) returns Mu
```

X div Y # Where Y is castable to Numeric and read only

### multi sub infix:<div>

```raku
multi sub infix:<div>(
    Numeric(Any) $a,
    Red::AST $b
) returns Mu
```

X div Y # Where X is castable to Numeric and read only

### multi sub infix:<div>

```raku
multi sub infix:<div>(
    Red::AST $a,
    Numeric(Any) $b is rw
) returns Mu
```

X div Y # Where Y is castable to Numeric and writable

### multi sub infix:<div>

```raku
multi sub infix:<div>(
    Numeric(Any) $a is rw,
    Red::AST $b
) returns Mu
```

X div Y # Where X is castable to Numeric and writable

### multi sub infix:<==>

```raku
multi sub infix:<==>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X == Y

### multi sub infix:<==>

```raku
multi sub infix:<==>(
    Red::AST $a,
    Numeric(Any) $b is rw
) returns Mu
```

X == Y # Where Y is castable to Numeric and writable

### multi sub infix:<==>

```raku
multi sub infix:<==>(
    Red::AST $a,
    Numeric(Any) $b
) returns Mu
```

X == Y # Where Y is castable to Numeric and read only

### multi sub infix:<==>

```raku
multi sub infix:<==>(
    Red::AST $a,
    Enumeration $b
) returns Mu
```

X == Y # Where LHS is AST and RHS is Enumeration

### multi sub infix:<==>

```raku
multi sub infix:<==>(
    Enumeration $a,
    Red::AST $b
) returns Mu
```

X == Y # Where X is castable to Numeric and writable

### multi sub infix:<==>

```raku
multi sub infix:<==>(
    Numeric(Any) $a is rw,
    Red::AST $b
) returns Mu
```

X == Y # Where X is castable to Numeric and writable

### multi sub infix:<==>

```raku
multi sub infix:<==>(
    Numeric(Any) $a,
    Red::AST $b
) returns Mu
```

X == Y # Where X is castable to Numeric and read only

### multi sub infix:<==>

```raku
multi sub infix:<==>(
    Red::AST $a where { ... },
    Date $b
) returns Mu
```

X == Y # Where X is castable to Numeric and read only

### multi sub infix:<!=>

```raku
multi sub infix:<!=>(
    Red::AST $a,
    Enumeration $b
) returns Mu
```

X != Y # Where Y is castable to Numeric and read only

### multi sub infix:<!=>

```raku
multi sub infix:<!=>(
    Red::AST $a,
    Numeric(Any) $b is rw
) returns Mu
```

X != Y # Where Y is castable to Numeric and read only

### multi sub infix:<!=>

```raku
multi sub infix:<!=>(
    Red::AST $a,
    Numeric(Any) $b
) returns Mu
```

X != Y # Where Y is castable to Numeric and read only

### multi sub infix:<!=>

```raku
multi sub infix:<!=>(
    Enumeration $a,
    Red::AST $b
) returns Mu
```

X != Y # Where X is castable to Numeric and writable

### multi sub infix:<!=>

```raku
multi sub infix:<!=>(
    Numeric(Any) $a is rw,
    Red::AST $b
) returns Mu
```

X != Y # Where X is castable to Numeric and writable

### multi sub infix:<!=>

```raku
multi sub infix:<!=>(
    Numeric(Any) $a,
    Red::AST $b
) returns Mu
```

X != Y # Where X is castable to Numeric and read only

### multi sub infix:<==>

```raku
multi sub infix:<==>(
    Red::AST $a,
    Date $b is rw
) returns Mu
```

X == Y X == Y # Where Y is Date and writable

### multi sub infix:<==>

```raku
multi sub infix:<==>(
    Red::AST $a,
    Date $b
) returns Mu
```

X == Y # Where Y is Date and read only

### multi sub infix:<==>

```raku
multi sub infix:<==>(
    Date $a is rw,
    Red::AST $b
) returns Mu
```

X == Y # Where X is Date and writable

### multi sub infix:<==>

```raku
multi sub infix:<==>(
    Date $a,
    Red::AST $b
) returns Mu
```

X == Y # Where X is Date and read only

### multi sub infix:<!=>

```raku
multi sub infix:<!=>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X != Y

### multi sub infix:<!=>

```raku
multi sub infix:<!=>(
    Red::AST $a,
    Date $b is rw
) returns Mu
```

X != Y # Where Y is Date and writable

### multi sub infix:<!=>

```raku
multi sub infix:<!=>(
    Red::AST $a,
    Date $b
) returns Mu
```

X != Y # Where Y is Date and read only

### multi sub infix:<!=>

```raku
multi sub infix:<!=>(
    Date $a is rw,
    Red::AST $b
) returns Mu
```

X != Y # Where X is Date and writable

### multi sub infix:<!=>

```raku
multi sub infix:<!=>(
    Date $a,
    Red::AST $b
) returns Mu
```

X != Y # Where X is Date and read only

### multi sub infix:<eq>

```raku
multi sub infix:<eq>(
    Red::AST $a,
    Str(Any) $b is rw
) returns Mu
```

X eq Y # Where Y is castable to Str and writable

### multi sub infix:<eq>

```raku
multi sub infix:<eq>(
    Red::AST $a,
    Str(Any) $b
) returns Mu
```

X eq Y # Where Y is castable to Str and read only

### multi sub infix:<eq>

```raku
multi sub infix:<eq>(
    Str(Any) $a is rw,
    Red::AST $b
) returns Mu
```

X eq Y # Where X is castable to Str and writable

### multi sub infix:<eq>

```raku
multi sub infix:<eq>(
    Str(Any) $a,
    Red::AST $b
) returns Mu
```

X eq Y # Where X is castable to Str and read only

### multi sub infix:<eq>

```raku
multi sub infix:<eq>(
    Red::AST $a where { ... },
    Date $b
) returns Mu
```

X eq Y # Where Y is any Red::AST that returns a DateTime

### multi sub infix:<eq>

```raku
multi sub infix:<eq>(
    Red::AST $a where { ... },
    Red::AST $b where { ... }
) returns Mu
```

X eq Y # Where both are AST that returns Str

### multi sub infix:<eq>

```raku
multi sub infix:<eq>(
    Red::AST $a,
    Enumeration $b
) returns Mu
```

X eq Y # Where LHS is an AST and RHS is Enumeration

### multi sub infix:<ne>

```raku
multi sub infix:<ne>(
    Red::AST $a,
    Str(Any) $b is rw
) returns Mu
```

X ne Y # Where Y is castable to Str and writable

### multi sub infix:<ne>

```raku
multi sub infix:<ne>(
    Red::AST $a,
    Str(Any) $b
) returns Mu
```

X ne Y # Where Y is castable to Str and read only

### multi sub infix:<ne>

```raku
multi sub infix:<ne>(
    Str(Any) $a is rw,
    Red::AST $b
) returns Mu
```

X ne Y # Where X is castable to Str and writable

### multi sub infix:<ne>

```raku
multi sub infix:<ne>(
    Str(Any) $a,
    Red::AST $b
) returns Mu
```

X ne Y # Where X is castable to Str and read only

### multi sub infix:«<»

```raku
multi sub infix:«<»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X < Y # Where Y is any Red::AST that returns a DateTime

### multi sub infix:«<»

```raku
multi sub infix:«<»(
    Red::AST $a,
    Numeric(Any) $b is rw
) returns Mu
```

X < Y # Where Y is castable to Numeric and writable

### multi sub infix:«<»

```raku
multi sub infix:«<»(
    Red::AST $a,
    Numeric(Any) $b
) returns Mu
```

X < Y # Where Y is castable to Numeric and read only

### multi sub infix:«<»

```raku
multi sub infix:«<»(
    Numeric(Any) $a is rw,
    Red::AST $b
) returns Mu
```

X < Y # Where X is castable to Numeric and writable

### multi sub infix:«<»

```raku
multi sub infix:«<»(
    Numeric(Any) $a,
    Red::AST $b
) returns Mu
```

X < Y # Where X is castable to Numeric and read only

### multi sub infix:«>»

```raku
multi sub infix:«>»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X > Y # Where Y is any Red::AST that returns a Numeric

### multi sub infix:«>»

```raku
multi sub infix:«>»(
    Red::AST $a,
    Numeric(Any) $b is rw
) returns Mu
```

X > Y # Where Y is castable to Numeric and writable

### multi sub infix:«>»

```raku
multi sub infix:«>»(
    Red::AST $a,
    Numeric(Any) $b
) returns Mu
```

X > Y # Where Y is castable to Numeric and read only

### multi sub infix:«>»

```raku
multi sub infix:«>»(
    Numeric(Any) $a is rw,
    Red::AST $b
) returns Mu
```

X > Y # Where X is castable to Numeric and writable

### multi sub infix:«>»

```raku
multi sub infix:«>»(
    Numeric(Any) $a,
    Red::AST $b
) returns Mu
```

X > Y # Where X is castable to Numeric and read only

### multi sub infix:«<=»

```raku
multi sub infix:«<=»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X <= Y # Where Y is any Red::AST that returns a Numeric

### multi sub infix:«<=»

```raku
multi sub infix:«<=»(
    Red::AST $a,
    Numeric(Any) $b is rw
) returns Mu
```

X <= Y # Where Y is castable to Numeric and read only

### multi sub infix:«<=»

```raku
multi sub infix:«<=»(
    Red::AST $a,
    Numeric(Any) $b
) returns Mu
```

X <= Y # Where Y is castable to Numeric and read only

### multi sub infix:«<=»

```raku
multi sub infix:«<=»(
    Numeric(Any) $a is rw,
    Red::AST $b
) returns Mu
```

X <= Y # Where X is castable to Numeric and writable

### multi sub infix:«<=»

```raku
multi sub infix:«<=»(
    Numeric(Any) $a,
    Red::AST $b
) returns Mu
```

X <= Y # Where X is castable to Numeric and read only

### multi sub infix:«>=»

```raku
multi sub infix:«>=»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X >= Y # Where Y is any Red::AST that returns a Numeric

### multi sub infix:«>=»

```raku
multi sub infix:«>=»(
    Red::AST $a,
    Numeric(Any) $b is rw
) returns Mu
```

X >= Y # Where Y is castable to Numeric and writable

### multi sub infix:«>=»

```raku
multi sub infix:«>=»(
    Red::AST $a,
    Numeric(Any) $b
) returns Mu
```

X >= Y # Where Y is castable to Numeric and read only

### multi sub infix:«>=»

```raku
multi sub infix:«>=»(
    Numeric(Any) $a is rw,
    Red::AST $b
) returns Mu
```

X >= Y # Where X is castable to Numeric and writable

### multi sub infix:«>=»

```raku
multi sub infix:«>=»(
    Numeric(Any) $a,
    Red::AST $b
) returns Mu
```

X >= Y # Where X is castable to Numeric and read only

### multi sub infix:«<»

```raku
multi sub infix:«<»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X < Y # Where Y is any Red::AST that returns a DateTime

### multi sub infix:«<»

```raku
multi sub infix:«<»(
    Red::AST $a,
    DateTime $b is rw
) returns Mu
```

X < Y # Where Y is DateTime and writable

### multi sub infix:«<»

```raku
multi sub infix:«<»(
    Red::AST $a,
    DateTime $b
) returns Mu
```

X < Y # Where Y is DateTime and read only

### multi sub infix:«<»

```raku
multi sub infix:«<»(
    DateTime $a is rw,
    Red::AST $b
) returns Mu
```

X < Y # Where X is DateTime and writable

### multi sub infix:«<»

```raku
multi sub infix:«<»(
    DateTime $a,
    Red::AST $b
) returns Mu
```

X < Y # Where X is DateTime and read only

### multi sub infix:«>»

```raku
multi sub infix:«>»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X > Y # Where Y is any Red::AST that returns a DateTime

### multi sub infix:«>»

```raku
multi sub infix:«>»(
    Red::AST $a,
    DateTime $b is rw
) returns Mu
```

X > Y # Where Y is DateTime and writable

### multi sub infix:«>»

```raku
multi sub infix:«>»(
    Red::AST $a,
    DateTime $b
) returns Mu
```

X > Y # Where Y is DateTime and read only

### multi sub infix:«>»

```raku
multi sub infix:«>»(
    DateTime $a is rw,
    Red::AST $b
) returns Mu
```

X > Y # Where X is DateTime and writable

### multi sub infix:«>»

```raku
multi sub infix:«>»(
    DateTime $a,
    Red::AST $b
) returns Mu
```

X > Y # Where X is DateTime and read only

### multi sub infix:«<=»

```raku
multi sub infix:«<=»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X <= Y # Where Y is any Red::AST that returns a DateTime

### multi sub infix:«<=»

```raku
multi sub infix:«<=»(
    Red::AST $a,
    DateTime $b is rw
) returns Mu
```

X <= Y # Where Y is DateTime and writable

### multi sub infix:«<=»

```raku
multi sub infix:«<=»(
    Red::AST $a,
    DateTime $b
) returns Mu
```

X <= Y # Where Y is DateTime and read only

### multi sub infix:«<=»

```raku
multi sub infix:«<=»(
    DateTime $a is rw,
    Red::AST $b
) returns Mu
```

X <= Y # Where X is DateTime and writable

### multi sub infix:«<=»

```raku
multi sub infix:«<=»(
    DateTime $a,
    Red::AST $b
) returns Mu
```

X <= Y # Where X is DateTime and read only

### multi sub infix:«>=»

```raku
multi sub infix:«>=»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X >= Y # Where Y is any Red::AST that returns a DateTime

### multi sub infix:«>=»

```raku
multi sub infix:«>=»(
    Red::AST $a,
    DateTime $b is rw
) returns Mu
```

X >= Y # Where Y is DateTime and writable

### multi sub infix:«>=»

```raku
multi sub infix:«>=»(
    Red::AST $a,
    DateTime $b
) returns Mu
```

X >= Y # Where Y is DateTime and read only

### multi sub infix:«>=»

```raku
multi sub infix:«>=»(
    DateTime $a is rw,
    Red::AST $b
) returns Mu
```

X >= Y # Where X is DateTime and writable

### multi sub infix:«>=»

```raku
multi sub infix:«>=»(
    DateTime $a,
    Red::AST $b
) returns Mu
```

X >= Y # Where X is DateTime and read only

### multi sub infix:«<»

```raku
multi sub infix:«<»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X < Y # Where Y is any Red::AST that returns a Date

### multi sub infix:«<»

```raku
multi sub infix:«<»(
    Red::AST $a,
    Date $b is rw
) returns Mu
```

X < Y # Where Y is Date and writable

### multi sub infix:«<»

```raku
multi sub infix:«<»(
    Red::AST $a,
    Date $b
) returns Mu
```

X < Y # Where Y is Date and read only

### multi sub infix:«<»

```raku
multi sub infix:«<»(
    Date $a is rw,
    Red::AST $b
) returns Mu
```

X < Y # Where X is Date and writable

### multi sub infix:«<»

```raku
multi sub infix:«<»(
    Date $a,
    Red::AST $b
) returns Mu
```

X < Y # Where X is Date and read only

### multi sub infix:«>»

```raku
multi sub infix:«>»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X > Y # Where Y is any Red::AST that returns a Date

### multi sub infix:«>»

```raku
multi sub infix:«>»(
    Red::AST $a,
    Date $b is rw
) returns Mu
```

X > Y # Where Y is Date and writable

### multi sub infix:«>»

```raku
multi sub infix:«>»(
    Red::AST $a,
    Date $b
) returns Mu
```

X > Y # Where Y is Date and read only

### multi sub infix:«>»

```raku
multi sub infix:«>»(
    Date $a is rw,
    Red::AST $b
) returns Mu
```

X > Y # Where X is Date and writable

### multi sub infix:«>»

```raku
multi sub infix:«>»(
    Date $a,
    Red::AST $b
) returns Mu
```

X > Y # Where X is Date and read only

### multi sub infix:«<=»

```raku
multi sub infix:«<=»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X <= Y # Where Y is any Red::AST that returns a Date

### multi sub infix:«<=»

```raku
multi sub infix:«<=»(
    Red::AST $a,
    Date $b is rw
) returns Mu
```

X <= Y # Where Y is Date and writable

### multi sub infix:«<=»

```raku
multi sub infix:«<=»(
    Red::AST $a,
    Date $b
) returns Mu
```

X <= Y # Where Y is Date and read only

### multi sub infix:«<=»

```raku
multi sub infix:«<=»(
    Date $a is rw,
    Red::AST $b
) returns Mu
```

X <= Y # Where X is Date and read only

### multi sub infix:«<=»

```raku
multi sub infix:«<=»(
    Date $a,
    Red::AST $b
) returns Mu
```

X <= Y # Where X is Date and read only

### multi sub infix:«>=»

```raku
multi sub infix:«>=»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X >= Y # Where Y is any Red::AST that returns a Date

### multi sub infix:«>=»

```raku
multi sub infix:«>=»(
    Red::AST $a,
    Date $b is rw
) returns Mu
```

X >= Y # Where Y is Date and writable

### multi sub infix:«>=»

```raku
multi sub infix:«>=»(
    Red::AST $a,
    Date $b
) returns Mu
```

X >= Y # Where Y is Date and read only

### multi sub infix:«>=»

```raku
multi sub infix:«>=»(
    Date $a is rw,
    Red::AST $b
) returns Mu
```

X >= Y # Where X is Date and writable

### multi sub infix:«>=»

```raku
multi sub infix:«>=»(
    Date $a,
    Red::AST $b
) returns Mu
```

X >= Y # Where X is Date and read only

### multi sub infix:<lt>

```raku
multi sub infix:<lt>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X lt Y

### multi sub infix:<lt>

```raku
multi sub infix:<lt>(
    Red::AST $a,
    Str(Any) $b is rw
) returns Mu
```

X lt Y # Where Y is castable to Str and writable

### multi sub infix:<lt>

```raku
multi sub infix:<lt>(
    Red::AST $a,
    Str(Any) $b
) returns Mu
```

X lt Y # Where Y is castable to Str and read only

### multi sub infix:<lt>

```raku
multi sub infix:<lt>(
    Str(Any) $a is rw,
    Red::AST $b
) returns Mu
```

X lt Y # Where X is castable to Str and writable

### multi sub infix:<lt>

```raku
multi sub infix:<lt>(
    Str(Any) $a,
    Red::AST $b
) returns Mu
```

X lt Y # Where X is castable to Str and read only

### multi sub infix:<gt>

```raku
multi sub infix:<gt>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X gt Y

### multi sub infix:<gt>

```raku
multi sub infix:<gt>(
    Red::AST $a,
    Str(Any) $b is rw
) returns Mu
```

X gt Y # Where Y is castable to Str and writable

### multi sub infix:<gt>

```raku
multi sub infix:<gt>(
    Red::AST $a,
    Str(Any) $b
) returns Mu
```

X gt Y # Where Y is castable to Str and read only

### multi sub infix:<gt>

```raku
multi sub infix:<gt>(
    Str(Any) $a is rw,
    Red::AST $b
) returns Mu
```

X gt Y # Where X is castable to Str and writable

### multi sub infix:<gt>

```raku
multi sub infix:<gt>(
    Str(Any) $a,
    Red::AST $b
) returns Mu
```

X gt Y # Where X is castable to Str and read only

### multi sub infix:<le>

```raku
multi sub infix:<le>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X le Y

### multi sub infix:<le>

```raku
multi sub infix:<le>(
    Red::AST $a,
    Str(Any) $b is rw
) returns Mu
```

X le Y # Where Y is castable to Str and writable

### multi sub infix:<le>

```raku
multi sub infix:<le>(
    Red::AST $a,
    Str(Any) $b
) returns Mu
```

X le Y # Where Y is castable to Str and read only

### multi sub infix:<le>

```raku
multi sub infix:<le>(
    Str(Any) $a is rw,
    Red::AST $b
) returns Mu
```

X le Y # Where X is castable to Str and writable

### multi sub infix:<le>

```raku
multi sub infix:<le>(
    Str(Any) $a,
    Red::AST $b
) returns Mu
```

X le Y # Where X is castable to Str and read only

### multi sub infix:<ge>

```raku
multi sub infix:<ge>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X ge Y

### multi sub infix:<ge>

```raku
multi sub infix:<ge>(
    Red::AST $a,
    Str(Any) $b is rw
) returns Mu
```

X ge Y # Where Y is castable to Str and writable

### multi sub infix:<ge>

```raku
multi sub infix:<ge>(
    Red::AST $a,
    Str(Any) $b
) returns Mu
```

X ge Y # Where Y is castable to Str and read only

### multi sub infix:<ge>

```raku
multi sub infix:<ge>(
    Str(Any) $a is rw,
    Red::AST $b
) returns Mu
```

X ge Y # Where X is castable to Str and writable

### multi sub infix:<ge>

```raku
multi sub infix:<ge>(
    Str(Any) $a,
    Red::AST $b
) returns Mu
```

X ge Y # Where X is castable to Str and read only

### multi sub infix:<%>

```raku
multi sub infix:<%>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X % Y

### multi sub infix:<%>

```raku
multi sub infix:<%>(
    Red::AST $a,
    Int(Any) $b is rw
) returns Mu
```

X % Y # Where X is castable to Int and writable

### multi sub infix:<%>

```raku
multi sub infix:<%>(
    Red::AST $a,
    Int(Any) $b
) returns Mu
```

X % Y # Where Y is castable to Int and read only

### multi sub infix:<%>

```raku
multi sub infix:<%>(
    Int(Any) $a is rw,
    Red::AST $b
) returns Mu
```

X % Y # Where X is castable to Int and writable

### multi sub infix:<%>

```raku
multi sub infix:<%>(
    Int(Any) $a,
    Red::AST $b
) returns Mu
```

X % Y # Where X is castable to Int and read only

### multi sub infix:<%%>

```raku
multi sub infix:<%%>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X %% Y

### multi sub infix:<%%>

```raku
multi sub infix:<%%>(
    Red::AST $a,
    Int(Any) $b is rw
) returns Mu
```

X %% Y # Where Y is castable to Int and writable

### multi sub infix:<%%>

```raku
multi sub infix:<%%>(
    Red::AST $a,
    Int(Any) $b
) returns Mu
```

X %% Y # Where Y is castable to Int and read only

### multi sub infix:<%%>

```raku
multi sub infix:<%%>(
    Int(Any) $a is rw,
    Red::AST $b
) returns Mu
```

X %% Y # Where X is castable to Int

### multi sub infix:<%%>

```raku
multi sub infix:<%%>(
    Int(Any) $a,
    Red::AST $b
) returns Mu
```

X %% Y # Where X is read only

### multi sub infix:<~>

```raku
multi sub infix:<~>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X ~ Y

### multi sub infix:<~>

```raku
multi sub infix:<~>(
    Red::AST $a,
    Str(Any) $b is rw
) returns Mu
```

X ~ Y Where Y is castable to Str and writable

### multi sub infix:<~>

```raku
multi sub infix:<~>(
    Red::AST $a,
    Str(Any) $b
) returns Mu
```

X ~ Y Where Y is castable to Str and read only

### multi sub infix:<~>

```raku
multi sub infix:<~>(
    Str(Any) $a is rw,
    Red::AST $b
) returns Mu
```

X ~ Y # Where X is castable to Str and writable

### multi sub infix:<~>

```raku
multi sub infix:<~>(
    Str(Any) $a,
    Red::AST $b
) returns Mu
```

X ~ Y # Where X is castable to Str and read only

### multi sub prefix:<not>

```raku
multi sub prefix:<not>(
    Red::AST $a
) returns Mu
```

not X # Where X is read only

### multi sub prefix:<not>

```raku
multi sub prefix:<not>(
    Red::AST $a is rw
) returns Mu
```

not X

### multi sub prefix:<!>

```raku
multi sub prefix:<!>(
    Red::AST $a
) returns Mu
```

!X

### multi sub prefix:<not>

```raku
multi sub prefix:<not>(
    Red::AST::In $a
) returns Mu
```

not X # Where X is a in

### multi sub prefix:<!>

```raku
multi sub prefix:<!>(
    Red::AST::In $a
) returns Mu
```

!X # Where X is a in

### multi sub prefix:<so>

```raku
multi sub prefix:<so>(
    Red::AST $a
) returns Mu
```

so X

### multi sub prefix:<?>

```raku
multi sub prefix:<?>(
    Red::AST $a
) returns Mu
```

?X

### multi sub infix:<AND>

```raku
multi sub infix:<AND>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X AND Y

### multi sub infix:<OR>

```raku
multi sub infix:<OR>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X OR Y

### multi sub infix:<∪>

```raku
multi sub infix:<∪>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

X ∪ Y # Where X and Y are ResultSeqs

### multi sub infix:<(|)>

```raku
multi sub infix:<(|)>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

X (|) Y # Where X and Y are ResultSeqs

### multi sub infix:<∩>

```raku
multi sub infix:<∩>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

X ∩ Y # Where X and Y are ResultSeqs

### multi sub infix:<(&)>

```raku
multi sub infix:<(&)>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

X (&) Y # Where X and Y are ResultSeqs

### multi sub infix:<⊖>

```raku
multi sub infix:<⊖>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

X ⊖ Y # Where X and Y are ResultSeqs

### multi sub infix:<(-)>

```raku
multi sub infix:<(-)>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

X (-) Y # Where X and Y are ResultSeqs

### multi sub infix:<in>

```raku
multi sub infix:<in>(
    Red::AST $a,
    Red::ResultSeq:D $b
) returns Mu
```

X in Y # Where Y is a ResultSeq

### multi sub infix:<⊂>

```raku
multi sub infix:<⊂>(
    Red::AST $a,
    Red::ResultSeq $b
) returns Mu
```

X ⊂ Y # Where Y is a ResultSeq

### multi sub infix:«(<)»

```raku
multi sub infix:«(<)»(
    Red::AST $a,
    Red::ResultSeq $b
) returns Mu
```

X (<) Y # Where Y is a ResultSeq

### multi sub infix:<⊃>

```raku
multi sub infix:<⊃>(
    Red::AST $a,
    Red::ResultSeq $b
) returns Mu
```

X ⊃ Y # Where Y is a ResultSeq

### multi sub infix:«(>)»

```raku
multi sub infix:«(>)»(
    Red::AST $a,
    Red::ResultSeq $b
) returns Mu
```

X (>) Y # Where Y is a ResultSeq

### multi sub infix:<in>

```raku
multi sub infix:<in>(
    Red::AST $a,
    $b where { ... }
) returns Mu
```

X in Y # Where Y is a positional but not a ResultSeq

### multi sub infix:<⊂>

```raku
multi sub infix:<⊂>(
    Red::AST $a,
    $b where { ... }
) returns Mu
```

X ⊂ Y # Where Y is a positional but not a ResultSeq

### multi sub infix:«(<)»

```raku
multi sub infix:«(<)»(
    Red::AST $a,
    $b where { ... }
) returns Mu
```

X (<) Y # Where Y is a positional but not a ResultSeq

### multi sub infix:<⊃>

```raku
multi sub infix:<⊃>(
    Red::AST $a,
    $b where { ... }
) returns Mu
```

X ⊃ Y # Where Y is a positional but not a ResultSeq

### multi sub infix:«(>)»

```raku
multi sub infix:«(>)»(
    Red::AST $a,
    $b where { ... }
) returns Mu
```

X (>) Y # Where Y is a positional but not a ResultSeq

### multi sub infix:<in>

```raku
multi sub infix:<in>(
    Red::AST $a,
    Red::AST::Select $b
) returns Mu
```

X in Y # where Y is a select

### multi sub infix:<⊂>

```raku
multi sub infix:<⊂>(
    Red::AST $a,
    Red::AST::Select $b
) returns Mu
```

X ⊂ Y # where Y is a select

### multi sub infix:«(<)»

```raku
multi sub infix:«(<)»(
    Red::AST $a,
    Red::AST::Select $b
) returns Mu
```

X (<) Y # where Y is a select

### multi sub infix:<⊃>

```raku
multi sub infix:<⊃>(
    Red::AST $a,
    Red::AST::Select $b
) returns Mu
```

X ⊃ Y # where Y is a select

### multi sub infix:«(>)»

```raku
multi sub infix:«(>)»(
    Red::AST $a,
    Red::AST::Select $b
) returns Mu
```

X (>) Y # Where Y is a select

