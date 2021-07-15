Red::Operators
--------------

### multi sub prefix:<-->

```perl6
multi sub prefix:<-->(
    Red::Column $a
) returns Mu
```

--X

### multi sub prefix:<++>

```perl6
multi sub prefix:<++>(
    Red::Column $a
) returns Mu
```

++X

### multi sub postfix:<-->

```perl6
multi sub postfix:<-->(
    Red::Column $a
) returns Mu
```

X--

### multi sub postfix:<++>

```perl6
multi sub postfix:<++>(
    Red::AST $a
) returns Mu
```

X++

### multi sub prefix:<->

```perl6
multi sub prefix:<->(
    Red::AST $a
) returns Mu
```

-X

### multi sub prefix:<+>

```perl6
multi sub prefix:<+>(
    Red::AST $a
) returns Mu
```

+X

### multi sub infix:<+>

```perl6
multi sub infix:<+>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X + Y

### multi sub infix:<+>

```perl6
multi sub infix:<+>(
    Red::AST $a,
    $b
) returns Mu
```

X + Y # Where Y is castable to Numeric

### multi sub infix:<+>

```perl6
multi sub infix:<+>(
    $a,
    Red::AST $b
) returns Mu
```

X + Y # Where X is castable to Numeric

### multi sub infix:<->

```perl6
multi sub infix:<->(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X - Y

### multi sub infix:<->

```perl6
multi sub infix:<->(
    Red::AST $a,
    $b
) returns Mu
```

X - Y # Where Y is castable to Numeric

### multi sub infix:<->

```perl6
multi sub infix:<->(
    $a,
    Red::AST $b
) returns Mu
```

X - Y # Where X is castable to Numeric

### multi sub infix:<*>

```perl6
multi sub infix:<*>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X * Y

### multi sub infix:<*>

```perl6
multi sub infix:<*>(
    Red::AST $a,
    $b
) returns Mu
```

X * Y # Where Y is castable to Numeric

### multi sub infix:<*>

```perl6
multi sub infix:<*>(
    $a,
    Red::AST $b
) returns Mu
```

X * Y

### multi sub infix:</>

```perl6
multi sub infix:</>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X / Y

### multi sub infix:</>

```perl6
multi sub infix:</>(
    Red::AST $a,
    $b
) returns Mu
```

X / Y # Where Y is castable to Numeric and read only

### multi sub infix:</>

```perl6
multi sub infix:</>(
    $a,
    Red::AST $b
) returns Mu
```

X / Y # Where X is castable to Numeric and read only

### multi sub infix:</>

```perl6
multi sub infix:</>(
    Red::AST $a,
    $b is rw
) returns Mu
```

X / Y # Where Y is castable to Numeric and writable

### multi sub infix:</>

```perl6
multi sub infix:</>(
    $a is rw,
    Red::AST $b
) returns Mu
```

X / Y # Where X is castable to Numeric and writable

### multi sub infix:<div>

```perl6
multi sub infix:<div>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X div Y

### multi sub infix:<div>

```perl6
multi sub infix:<div>(
    Red::AST $a,
    $b
) returns Mu
```

X div Y # Where Y is castable to Numeric and read only

### multi sub infix:<div>

```perl6
multi sub infix:<div>(
    $a,
    Red::AST $b
) returns Mu
```

X div Y # Where X is castable to Numeric and read only

### multi sub infix:<div>

```perl6
multi sub infix:<div>(
    Red::AST $a,
    $b is rw
) returns Mu
```

X div Y # Where Y is castable to Numeric and writable

### multi sub infix:<div>

```perl6
multi sub infix:<div>(
    $a is rw,
    Red::AST $b
) returns Mu
```

X div Y # Where X is castable to Numeric and writable

### multi sub infix:<==>

```perl6
multi sub infix:<==>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X == Y

### multi sub infix:<==>

```perl6
multi sub infix:<==>(
    Red::AST $a,
    $b is rw
) returns Mu
```

X == Y # Where Y is castable to Numeric and writable

### multi sub infix:<==>

```perl6
multi sub infix:<==>(
    Red::AST $a,
    $b
) returns Mu
```

X == Y # Where Y is castable to Numeric and read only

### multi sub infix:<==>

```perl6
multi sub infix:<==>(
    $a is rw,
    Red::AST $b
) returns Mu
```

X == Y # Where X is castable to Numeric and writable

### multi sub infix:<==>

```perl6
multi sub infix:<==>(
    $a,
    Red::AST $b
) returns Mu
```

X == Y # Where X is castable to Numeric and read only

### multi sub infix:<==>

```perl6
multi sub infix:<==>(
    Red::AST $a where { ... },
    Date $b
) returns Mu
```

X == Y # Where X is castable to Numeric and read only

### multi sub infix:<!=>

```perl6
multi sub infix:<!=>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X != Y # Where Y is castable to Numeric and writable

### multi sub infix:<!=>

```perl6
multi sub infix:<!=>(
    Red::AST $a,
    $b is rw
) returns Mu
```

X != Y # Where Y is castable to Numeric and read only

### multi sub infix:<!=>

```perl6
multi sub infix:<!=>(
    Red::AST $a,
    $b
) returns Mu
```

X != Y # Where Y is castable to Numeric and read only

### multi sub infix:<!=>

```perl6
multi sub infix:<!=>(
    $a is rw,
    Red::AST $b
) returns Mu
```

X != Y # Where X is castable to Numeric and writable

### multi sub infix:<!=>

```perl6
multi sub infix:<!=>(
    $a,
    Red::AST $b
) returns Mu
```

X != Y # Where X is castable to Numeric and read only

### multi sub infix:<==>

```perl6
multi sub infix:<==>(
    Red::AST $a,
    Date $b is rw
) returns Mu
```

X == Y X == Y # Where Y is Date and writable

### multi sub infix:<==>

```perl6
multi sub infix:<==>(
    Red::AST $a,
    Date $b
) returns Mu
```

X == Y # Where Y is Date and read only

### multi sub infix:<==>

```perl6
multi sub infix:<==>(
    Date $a is rw,
    Red::AST $b
) returns Mu
```

X == Y # Where X is Date and writable

### multi sub infix:<==>

```perl6
multi sub infix:<==>(
    Date $a,
    Red::AST $b
) returns Mu
```

X == Y # Where X is Date and read only

### multi sub infix:<!=>

```perl6
multi sub infix:<!=>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X != Y

### multi sub infix:<!=>

```perl6
multi sub infix:<!=>(
    Red::AST $a,
    Date $b is rw
) returns Mu
```

X != Y # Where Y is Date and writable

### multi sub infix:<!=>

```perl6
multi sub infix:<!=>(
    Red::AST $a,
    Date $b
) returns Mu
```

X != Y # Where Y is Date and read only

### multi sub infix:<!=>

```perl6
multi sub infix:<!=>(
    Date $a is rw,
    Red::AST $b
) returns Mu
```

X != Y # Where X is Date and writable

### multi sub infix:<!=>

```perl6
multi sub infix:<!=>(
    Date $a,
    Red::AST $b
) returns Mu
```

X != Y # Where X is Date and read only

### multi sub infix:<eq>

```perl6
multi sub infix:<eq>(
    Red::AST $a,
    $b is rw
) returns Mu
```

X eq Y # Where Y is castable to Str and writable

### multi sub infix:<eq>

```perl6
multi sub infix:<eq>(
    Red::AST $a,
    $b
) returns Mu
```

X eq Y # Where Y is castable to Str and read only

### multi sub infix:<eq>

```perl6
multi sub infix:<eq>(
    $a is rw,
    Red::AST $b
) returns Mu
```

X eq Y # Where X is castable to Str and writable

### multi sub infix:<eq>

```perl6
multi sub infix:<eq>(
    $a,
    Red::AST $b
) returns Mu
```

X eq Y # Where X is castable to Str and read only

### multi sub infix:<eq>

```perl6
multi sub infix:<eq>(
    Red::AST $a where { ... },
    Date $b
) returns Mu
```

X eq Y # Where Y is any Red::AST that returns a DateTime

### multi sub infix:<eq>

```perl6
multi sub infix:<eq>(
    Red::AST $a where { ... },
    Red::AST $b where { ... }
) returns Mu
```

X eq Y # Where both are AST that returns Str

### multi sub infix:<ne>

```perl6
multi sub infix:<ne>(
    Red::AST $a,
    $b is rw
) returns Mu
```

X ne Y # Where Y is castable to Str and writable

### multi sub infix:<ne>

```perl6
multi sub infix:<ne>(
    Red::AST $a,
    $b
) returns Mu
```

X ne Y # Where Y is castable to Str and read only

### multi sub infix:<ne>

```perl6
multi sub infix:<ne>(
    $a is rw,
    Red::AST $b
) returns Mu
```

X ne Y # Where X is castable to Str and writable

### multi sub infix:<ne>

```perl6
multi sub infix:<ne>(
    $a,
    Red::AST $b
) returns Mu
```

X ne Y # Where X is castable to Str and read only

### multi sub infix:«<»

```perl6
multi sub infix:«<»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X < Y # Where Y is any Red::AST that returns a DateTime

### multi sub infix:«<»

```perl6
multi sub infix:«<»(
    Red::AST $a,
    $b is rw
) returns Mu
```

X < Y # Where Y is castable to Numeric and writable

### multi sub infix:«<»

```perl6
multi sub infix:«<»(
    Red::AST $a,
    $b
) returns Mu
```

X < Y # Where Y is castable to Numeric and read only

### multi sub infix:«<»

```perl6
multi sub infix:«<»(
    $a is rw,
    Red::AST $b
) returns Mu
```

X < Y # Where X is castable to Numeric and writable

### multi sub infix:«<»

```perl6
multi sub infix:«<»(
    $a,
    Red::AST $b
) returns Mu
```

X < Y # Where X is castable to Numeric and read only

### multi sub infix:«>»

```perl6
multi sub infix:«>»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X > Y # Where Y is any Red::AST that returns a Numeric

### multi sub infix:«>»

```perl6
multi sub infix:«>»(
    Red::AST $a,
    $b is rw
) returns Mu
```

X > Y # Where Y is castable to Numeric and writable

### multi sub infix:«>»

```perl6
multi sub infix:«>»(
    Red::AST $a,
    $b
) returns Mu
```

X > Y # Where Y is castable to Numeric and read only

### multi sub infix:«>»

```perl6
multi sub infix:«>»(
    $a is rw,
    Red::AST $b
) returns Mu
```

X > Y # Where X is castable to Numeric and writable

### multi sub infix:«>»

```perl6
multi sub infix:«>»(
    $a,
    Red::AST $b
) returns Mu
```

X > Y # Where X is castable to Numeric and read only

### multi sub infix:«<=»

```perl6
multi sub infix:«<=»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X <= Y # Where Y is any Red::AST that returns a Numeric

### multi sub infix:«<=»

```perl6
multi sub infix:«<=»(
    Red::AST $a,
    $b is rw
) returns Mu
```

X <= Y # Where Y is castable to Numeric and read only

### multi sub infix:«<=»

```perl6
multi sub infix:«<=»(
    Red::AST $a,
    $b
) returns Mu
```

X <= Y # Where Y is castable to Numeric and read only

### multi sub infix:«<=»

```perl6
multi sub infix:«<=»(
    $a is rw,
    Red::AST $b
) returns Mu
```

X <= Y # Where X is castable to Numeric and writable

### multi sub infix:«<=»

```perl6
multi sub infix:«<=»(
    $a,
    Red::AST $b
) returns Mu
```

X <= Y # Where X is castable to Numeric and read only

### multi sub infix:«>=»

```perl6
multi sub infix:«>=»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X >= Y # Where Y is any Red::AST that returns a DateTime

### multi sub infix:«>=»

```perl6
multi sub infix:«>=»(
    Red::AST $a,
    $b is rw
) returns Mu
```

X >= Y # Where Y is castable to Numeric and writable

### multi sub infix:«>=»

```perl6
multi sub infix:«>=»(
    Red::AST $a,
    $b
) returns Mu
```

X >= Y # Where Y is castable to Numeric and read only

### multi sub infix:«>=»

```perl6
multi sub infix:«>=»(
    $a is rw,
    Red::AST $b
) returns Mu
```

X >= Y # Where X is castable to Numeric and writable

### multi sub infix:«>=»

```perl6
multi sub infix:«>=»(
    $a,
    Red::AST $b
) returns Mu
```

X >= Y # Where X is castable to Numeric and read only

### multi sub infix:«<»

```perl6
multi sub infix:«<»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X < Y # Where Y is any Red::AST that returns a DateTime

### multi sub infix:«<»

```perl6
multi sub infix:«<»(
    Red::AST $a,
    DateTime $b is rw
) returns Mu
```

X < Y # Where Y is DateTime and writable

### multi sub infix:«<»

```perl6
multi sub infix:«<»(
    Red::AST $a,
    DateTime $b
) returns Mu
```

X < Y # Where Y is DateTime and read only

### multi sub infix:«<»

```perl6
multi sub infix:«<»(
    DateTime $a is rw,
    Red::AST $b
) returns Mu
```

X < Y # Where X is DateTime and writable

### multi sub infix:«<»

```perl6
multi sub infix:«<»(
    DateTime $a,
    Red::AST $b
) returns Mu
```

X < Y # Where X is DateTime and read only

### multi sub infix:«>»

```perl6
multi sub infix:«>»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X > Y # Where Y is any Red::AST that returns a DateTime

### multi sub infix:«>»

```perl6
multi sub infix:«>»(
    Red::AST $a,
    DateTime $b is rw
) returns Mu
```

X > Y # Where Y is DateTime and writable

### multi sub infix:«>»

```perl6
multi sub infix:«>»(
    Red::AST $a,
    DateTime $b
) returns Mu
```

X > Y # Where Y is DateTime and read only

### multi sub infix:«>»

```perl6
multi sub infix:«>»(
    DateTime $a is rw,
    Red::AST $b
) returns Mu
```

X > Y # Where X is DateTime and writable

### multi sub infix:«>»

```perl6
multi sub infix:«>»(
    DateTime $a,
    Red::AST $b
) returns Mu
```

X > Y # Where X is DateTime and read only

### multi sub infix:«<=»

```perl6
multi sub infix:«<=»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X <= Y # Where Y is any Red::AST that returns a DateTime

### multi sub infix:«<=»

```perl6
multi sub infix:«<=»(
    Red::AST $a,
    DateTime $b is rw
) returns Mu
```

X <= Y # Where Y is DateTime and writable

### multi sub infix:«<=»

```perl6
multi sub infix:«<=»(
    Red::AST $a,
    DateTime $b
) returns Mu
```

X <= Y # Where Y is DateTime and read only

### multi sub infix:«<=»

```perl6
multi sub infix:«<=»(
    DateTime $a is rw,
    Red::AST $b
) returns Mu
```

X <= Y # Where X is DateTime and writable

### multi sub infix:«<=»

```perl6
multi sub infix:«<=»(
    DateTime $a,
    Red::AST $b
) returns Mu
```

X <= Y # Where X is DateTime and read only

### multi sub infix:«>=»

```perl6
multi sub infix:«>=»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X >= Y # Where Y is any Red::AST that returns a DateTime

### multi sub infix:«>=»

```perl6
multi sub infix:«>=»(
    Red::AST $a,
    DateTime $b is rw
) returns Mu
```

X >= Y # Where Y is DateTime and writable

### multi sub infix:«>=»

```perl6
multi sub infix:«>=»(
    Red::AST $a,
    DateTime $b
) returns Mu
```

X >= Y # Where Y is DateTime and read only

### multi sub infix:«>=»

```perl6
multi sub infix:«>=»(
    DateTime $a is rw,
    Red::AST $b
) returns Mu
```

X >= Y # Where X is DateTime and writable

### multi sub infix:«>=»

```perl6
multi sub infix:«>=»(
    DateTime $a,
    Red::AST $b
) returns Mu
```

X >= Y # Where X is DateTime and read only

### multi sub infix:«<»

```perl6
multi sub infix:«<»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X < Y # Where Y is any Red::AST that returns a Date

### multi sub infix:«<»

```perl6
multi sub infix:«<»(
    Red::AST $a,
    Date $b is rw
) returns Mu
```

X < Y # Where Y is Date and writable

### multi sub infix:«<»

```perl6
multi sub infix:«<»(
    Red::AST $a,
    Date $b
) returns Mu
```

X < Y # Where Y is Date and read only

### multi sub infix:«<»

```perl6
multi sub infix:«<»(
    Date $a is rw,
    Red::AST $b
) returns Mu
```

X < Y # Where X is Date and writable

### multi sub infix:«<»

```perl6
multi sub infix:«<»(
    Date $a,
    Red::AST $b
) returns Mu
```

X < Y # Where X is Date and read only

### multi sub infix:«>»

```perl6
multi sub infix:«>»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X > Y # Where Y is any Red::AST that returns a Date

### multi sub infix:«>»

```perl6
multi sub infix:«>»(
    Red::AST $a,
    Date $b is rw
) returns Mu
```

X > Y # Where Y is Date and writable

### multi sub infix:«>»

```perl6
multi sub infix:«>»(
    Red::AST $a,
    Date $b
) returns Mu
```

X > Y # Where Y is Date and read only

### multi sub infix:«>»

```perl6
multi sub infix:«>»(
    Date $a is rw,
    Red::AST $b
) returns Mu
```

X > Y # Where X is Date and writable

### multi sub infix:«>»

```perl6
multi sub infix:«>»(
    Date $a,
    Red::AST $b
) returns Mu
```

X > Y # Where X is Date and read only

### multi sub infix:«<=»

```perl6
multi sub infix:«<=»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X <= Y # Where Y is any Red::AST that returns a Date

### multi sub infix:«<=»

```perl6
multi sub infix:«<=»(
    Red::AST $a,
    Date $b is rw
) returns Mu
```

X <= Y # Where Y is Date and writable

### multi sub infix:«<=»

```perl6
multi sub infix:«<=»(
    Red::AST $a,
    Date $b
) returns Mu
```

X <= Y # Where Y is Date and read only

### multi sub infix:«<=»

```perl6
multi sub infix:«<=»(
    Date $a is rw,
    Red::AST $b
) returns Mu
```

X <= Y # Where X is Date and read only

### multi sub infix:«<=»

```perl6
multi sub infix:«<=»(
    Date $a,
    Red::AST $b
) returns Mu
```

X <= Y # Where X is Date and read only

### multi sub infix:«>=»

```perl6
multi sub infix:«>=»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

X >= Y # Where Y is any Red::AST that returns a Date

### multi sub infix:«>=»

```perl6
multi sub infix:«>=»(
    Red::AST $a,
    Date $b is rw
) returns Mu
```

X >= Y # Where Y is Date and writable

### multi sub infix:«>=»

```perl6
multi sub infix:«>=»(
    Red::AST $a,
    Date $b
) returns Mu
```

X >= Y # Where Y is Date and read only

### multi sub infix:«>=»

```perl6
multi sub infix:«>=»(
    Date $a is rw,
    Red::AST $b
) returns Mu
```

X >= Y # Where X is Date and writable

### multi sub infix:«>=»

```perl6
multi sub infix:«>=»(
    Date $a,
    Red::AST $b
) returns Mu
```

X >= Y # Where X is Date and read only

### multi sub infix:<lt>

```perl6
multi sub infix:<lt>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X lt Y

### multi sub infix:<lt>

```perl6
multi sub infix:<lt>(
    Red::AST $a,
    $b is rw
) returns Mu
```

X lt Y # Where Y is castable to Str and writable

### multi sub infix:<lt>

```perl6
multi sub infix:<lt>(
    Red::AST $a,
    $b
) returns Mu
```

X lt Y # Where Y is castable to Str and read only

### multi sub infix:<lt>

```perl6
multi sub infix:<lt>(
    $a is rw,
    Red::AST $b
) returns Mu
```

X lt Y # Where X is castable to Str and writable

### multi sub infix:<lt>

```perl6
multi sub infix:<lt>(
    $a,
    Red::AST $b
) returns Mu
```

X lt Y # Where X is castable to Str and read only

### multi sub infix:<gt>

```perl6
multi sub infix:<gt>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X gt Y

### multi sub infix:<gt>

```perl6
multi sub infix:<gt>(
    Red::AST $a,
    $b is rw
) returns Mu
```

X gt Y # Where Y is castable to Str and writable

### multi sub infix:<gt>

```perl6
multi sub infix:<gt>(
    Red::AST $a,
    $b
) returns Mu
```

X gt Y # Where Y is castable to Str and read only

### multi sub infix:<gt>

```perl6
multi sub infix:<gt>(
    $a is rw,
    Red::AST $b
) returns Mu
```

X gt Y # Where X is castable to Str and writable

### multi sub infix:<gt>

```perl6
multi sub infix:<gt>(
    $a,
    Red::AST $b
) returns Mu
```

X gt Y # Where X is castable to Str and read only

### multi sub infix:<le>

```perl6
multi sub infix:<le>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X le Y

### multi sub infix:<le>

```perl6
multi sub infix:<le>(
    Red::AST $a,
    $b is rw
) returns Mu
```

X le Y # Where Y is castable to Str and writable

### multi sub infix:<le>

```perl6
multi sub infix:<le>(
    Red::AST $a,
    $b
) returns Mu
```

X le Y # Where Y is castable to Str and read only

### multi sub infix:<le>

```perl6
multi sub infix:<le>(
    $a is rw,
    Red::AST $b
) returns Mu
```

X le Y # Where X is castable to Str and writable

### multi sub infix:<le>

```perl6
multi sub infix:<le>(
    $a,
    Red::AST $b
) returns Mu
```

X le Y # Where X is castable to Str and read only

### multi sub infix:<ge>

```perl6
multi sub infix:<ge>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X ge Y

### multi sub infix:<ge>

```perl6
multi sub infix:<ge>(
    Red::AST $a,
    $b is rw
) returns Mu
```

X ge Y # Where Y is castable to Str and writable

### multi sub infix:<ge>

```perl6
multi sub infix:<ge>(
    Red::AST $a,
    $b
) returns Mu
```

X ge Y # Where Y is castable to Str and read only

### multi sub infix:<ge>

```perl6
multi sub infix:<ge>(
    $a is rw,
    Red::AST $b
) returns Mu
```

X ge Y # Where X is castable to Str and writable

### multi sub infix:<ge>

```perl6
multi sub infix:<ge>(
    $a,
    Red::AST $b
) returns Mu
```

X ge Y # Where X is castable to Str and read only

### multi sub infix:<%>

```perl6
multi sub infix:<%>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X % Y

### multi sub infix:<%>

```perl6
multi sub infix:<%>(
    Red::AST $a,
    $b is rw
) returns Mu
```

X % Y # Where X is castable to Int and writable

### multi sub infix:<%>

```perl6
multi sub infix:<%>(
    Red::AST $a,
    $b
) returns Mu
```

X % Y # Where Y is castable to Int and read only

### multi sub infix:<%>

```perl6
multi sub infix:<%>(
    $a is rw,
    Red::AST $b
) returns Mu
```

X % Y # Where X is castable to Int and writable

### multi sub infix:<%>

```perl6
multi sub infix:<%>(
    $a,
    Red::AST $b
) returns Mu
```

X % Y # Where X is castable to Int and read only

### multi sub infix:<%%>

```perl6
multi sub infix:<%%>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X %% Y

### multi sub infix:<%%>

```perl6
multi sub infix:<%%>(
    Red::AST $a,
    $b is rw
) returns Mu
```

X %% Y # Where Y is castable to Int and writable

### multi sub infix:<%%>

```perl6
multi sub infix:<%%>(
    Red::AST $a,
    $b
) returns Mu
```

X %% Y # Where Y is castable to Int and read only

### multi sub infix:<%%>

```perl6
multi sub infix:<%%>(
    $a is rw,
    Red::AST $b
) returns Mu
```

X %% Y # Where X is castable to Int

### multi sub infix:<%%>

```perl6
multi sub infix:<%%>(
    $a,
    Red::AST $b
) returns Mu
```

X %% Y # Where X is read only

### multi sub infix:<~>

```perl6
multi sub infix:<~>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X ~ Y

### multi sub infix:<~>

```perl6
multi sub infix:<~>(
    Red::AST $a,
    $b is rw
) returns Mu
```

X ~ Y Where Y is castable to Str and writable

### multi sub infix:<~>

```perl6
multi sub infix:<~>(
    Red::AST $a,
    $b
) returns Mu
```

X ~ Y Where Y is castable to Str and read only

### multi sub infix:<~>

```perl6
multi sub infix:<~>(
    $a is rw,
    Red::AST $b
) returns Mu
```

X ~ Y # Where X is castable to Str and writable

### multi sub infix:<~>

```perl6
multi sub infix:<~>(
    $a,
    Red::AST $b
) returns Mu
```

X ~ Y # Where X is castable to Str and read only

### multi sub prefix:<not>

```perl6
multi sub prefix:<not>(
    Red::AST $a
) returns Mu
```

not X # Where X is read only

### multi sub prefix:<not>

```perl6
multi sub prefix:<not>(
    Red::AST $a is rw
) returns Mu
```

not X

### multi sub prefix:<!>

```perl6
multi sub prefix:<!>(
    Red::AST $a
) returns Mu
```

!X

### multi sub prefix:<not>

```perl6
multi sub prefix:<not>(
    Red::AST::In $a
) returns Mu
```

not X # Where X is a in

### multi sub prefix:<!>

```perl6
multi sub prefix:<!>(
    Red::AST::In $a
) returns Mu
```

!X # Where X is a in

### multi sub prefix:<so>

```perl6
multi sub prefix:<so>(
    Red::AST $a
) returns Mu
```

so X

### multi sub prefix:<?>

```perl6
multi sub prefix:<?>(
    Red::AST $a
) returns Mu
```

?X

### multi sub infix:<AND>

```perl6
multi sub infix:<AND>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X AND Y

### multi sub infix:<OR>

```perl6
multi sub infix:<OR>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X OR Y

### multi sub infix:<∪>

```perl6
multi sub infix:<∪>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

X ∪ Y # Where X and Y are ResultSeqs

### multi sub infix:<(|)>

```perl6
multi sub infix:<(|)>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

X (|) Y # Where X and Y are ResultSeqs

### multi sub infix:<∩>

```perl6
multi sub infix:<∩>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

X ∩ Y # Where X and Y are ResultSeqs

### multi sub infix:<(&)>

```perl6
multi sub infix:<(&)>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

X (&) Y # Where X and Y are ResultSeqs

### multi sub infix:<⊖>

```perl6
multi sub infix:<⊖>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

X ⊖ Y # Where X and Y are ResultSeqs

### multi sub infix:<(-)>

```perl6
multi sub infix:<(-)>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

X (-) Y # Where X and Y are ResultSeqs

### multi sub infix:<in>

```perl6
multi sub infix:<in>(
    Red::AST $a,
    Red::ResultSeq:D $b
) returns Mu
```

X in Y # Where Y is a ResultSeq

### multi sub infix:<⊂>

```perl6
multi sub infix:<⊂>(
    Red::AST $a,
    Red::ResultSeq $b
) returns Mu
```

X ⊂ Y # Where Y is a ResultSeq

### multi sub infix:«(<)»

```perl6
multi sub infix:«(<)»(
    Red::AST $a,
    Red::ResultSeq $b
) returns Mu
```

X (<) Y # Where Y is a ResultSeq

### multi sub infix:<⊃>

```perl6
multi sub infix:<⊃>(
    Red::AST $a,
    Red::ResultSeq $b
) returns Mu
```

X ⊃ Y # Where Y is a ResultSeq

### multi sub infix:«(>)»

```perl6
multi sub infix:«(>)»(
    Red::AST $a,
    Red::ResultSeq $b
) returns Mu
```

X (>) Y # Where Y is a ResultSeq

### multi sub infix:<in>

```perl6
multi sub infix:<in>(
    Red::AST $a,
    $b where { ... }
) returns Mu
```

X in Y # Where Y is a positional but not a ResultSeq

### multi sub infix:<⊂>

```perl6
multi sub infix:<⊂>(
    Red::AST $a,
    $b where { ... }
) returns Mu
```

X ⊂ Y # Where Y is a positional but not a ResultSeq

### multi sub infix:«(<)»

```perl6
multi sub infix:«(<)»(
    Red::AST $a,
    $b where { ... }
) returns Mu
```

X (<) Y # Where Y is a positional but not a ResultSeq

### multi sub infix:<⊃>

```perl6
multi sub infix:<⊃>(
    Red::AST $a,
    $b where { ... }
) returns Mu
```

X ⊃ Y # Where Y is a positional but not a ResultSeq

### multi sub infix:«(>)»

```perl6
multi sub infix:«(>)»(
    Red::AST $a,
    $b where { ... }
) returns Mu
```

X (>) Y # Where Y is a positional but not a ResultSeq

### multi sub infix:<in>

```perl6
multi sub infix:<in>(
    Red::AST $a,
    Red::AST::Select $b
) returns Mu
```

X in Y # where Y is a select

### multi sub infix:<⊂>

```perl6
multi sub infix:<⊂>(
    Red::AST $a,
    Red::AST::Select $b
) returns Mu
```

X ⊂ Y # where Y is a select

### multi sub infix:«(<)»

```perl6
multi sub infix:«(<)»(
    Red::AST $a,
    Red::AST::Select $b
) returns Mu
```

X (<) Y # where Y is a select

### multi sub infix:<⊃>

```perl6
multi sub infix:<⊃>(
    Red::AST $a,
    Red::AST::Select $b
) returns Mu
```

X ⊃ Y # where Y is a select

### multi sub infix:«(>)»

```perl6
multi sub infix:«(>)»(
    Red::AST $a,
    Red::AST::Select $b
) returns Mu
```

X (>) Y # Where Y is a select

