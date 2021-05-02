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

### multi sub infix:<->

```raku
multi sub infix:<->(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X - Y

### multi sub infix:<*>

```raku
multi sub infix:<*>(
    Red::AST $a,
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

### multi sub infix:<div>

```raku
multi sub infix:<div>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X div Y

### multi sub infix:<==>

```raku
multi sub infix:<==>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

==

### multi sub infix:<!=>

```raku
multi sub infix:<!=>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

!=

### multi sub infix:<==>

```raku
multi sub infix:<==>(
    Red::AST $a,
    Date $b is rw
) returns Mu
```

==

### multi sub infix:<!=>

```raku
multi sub infix:<!=>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

!=

### multi sub infix:<eq>

```raku
multi sub infix:<eq>(
    Red::AST $a,
    Str(Any) $b is rw
) returns Mu
```

eq

### multi sub infix:<ne>

```raku
multi sub infix:<ne>(
    Red::AST $a,
    Str(Any) $b is rw
) returns Mu
```

ne

### multi sub infix:«<»

```raku
multi sub infix:«<»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

<

### multi sub infix:«>»

```raku
multi sub infix:«>»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

>

### multi sub infix:«<=»

```raku
multi sub infix:«<=»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

<=

### multi sub infix:«>=»

```raku
multi sub infix:«>=»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

>=

### multi sub infix:«<»

```raku
multi sub infix:«<»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

<

### multi sub infix:«>»

```raku
multi sub infix:«>»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

>

### multi sub infix:«<=»

```raku
multi sub infix:«<=»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

<=

### multi sub infix:«>=»

```raku
multi sub infix:«>=»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

>=

### multi sub infix:«<»

```raku
multi sub infix:«<»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

<

### multi sub infix:«>»

```raku
multi sub infix:«>»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

>

### multi sub infix:«<=»

```raku
multi sub infix:«<=»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

<=

### multi sub infix:«>=»

```raku
multi sub infix:«>=»(
    Red::AST $a where { ... },
    Red::AST $b
) returns Mu
```

>=

### multi sub infix:<lt>

```raku
multi sub infix:<lt>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

lt

### multi sub infix:<gt>

```raku
multi sub infix:<gt>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

gt

### multi sub infix:<le>

```raku
multi sub infix:<le>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

le

### multi sub infix:<ge>

```raku
multi sub infix:<ge>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

ge

### multi sub infix:<%>

```raku
multi sub infix:<%>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

%

### multi sub infix:<%%>

```raku
multi sub infix:<%%>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

%%

### multi sub infix:<~>

```raku
multi sub infix:<~>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

~

### multi sub prefix:<not>

```raku
multi sub prefix:<not>(
    Red::AST $a
) returns Mu
```

not X

### multi sub prefix:<!>

```raku
multi sub prefix:<!>(
    Red::AST::In $a
) returns Mu
```

!X

### multi sub prefix:<so>

```raku
multi sub prefix:<so>(
    Red::AST $a
) returns Mu
```

so

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

AND

### multi sub infix:<OR>

```raku
multi sub infix:<OR>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

OR

### multi sub infix:<∪>

```raku
multi sub infix:<∪>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

∪

### multi sub infix:<(|)>

```raku
multi sub infix:<(|)>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

(|)

### multi sub infix:<∩>

```raku
multi sub infix:<∩>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

∩

### multi sub infix:<(&)>

```raku
multi sub infix:<(&)>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

(&)

### multi sub infix:<⊖>

```raku
multi sub infix:<⊖>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

⊖

### multi sub infix:<(-)>

```raku
multi sub infix:<(-)>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

(-)

### multi sub infix:<in>

```raku
multi sub infix:<in>(
    Red::AST $a,
    Red::ResultSeq:D $b
) returns Mu
```

in

### multi sub infix:<⊂>

```raku
multi sub infix:<⊂>(
    Red::AST $a,
    Red::ResultSeq $b
) returns Mu
```

⊂

### multi sub infix:«(<)»

```raku
multi sub infix:«(<)»(
    Red::AST $a,
    Red::ResultSeq $b
) returns Mu
```

(<)

### multi sub infix:<⊃>

```raku
multi sub infix:<⊃>(
    Red::AST $a,
    Red::ResultSeq $b
) returns Mu
```

⊃

### multi sub infix:«(>)»

```raku
multi sub infix:«(>)»(
    Red::AST $a,
    Red::ResultSeq $b
) returns Mu
```

(>)

