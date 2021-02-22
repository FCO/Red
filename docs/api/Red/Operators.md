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

### multi sub infix:<->

```perl6
multi sub infix:<->(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X - Y

### multi sub infix:<*>

```perl6
multi sub infix:<*>(
    Red::AST $a,
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

### multi sub infix:<div>

```perl6
multi sub infix:<div>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

X div Y

### multi sub infix:<==>

```perl6
multi sub infix:<==>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

==

### multi sub infix:<!=>

```perl6
multi sub infix:<!=>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

!=

### multi sub infix:<==>

```perl6
multi sub infix:<==>(
    Red::AST $a,
    Date $b is rw
) returns Mu
```

==

### multi sub infix:<!=>

```perl6
multi sub infix:<!=>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

!=

### multi sub infix:<eq>

```perl6
multi sub infix:<eq>(
    Red::AST $a,
    $b is rw
) returns Mu
```

eq

### multi sub infix:<ne>

```perl6
multi sub infix:<ne>(
    Red::AST $a,
    $b is rw
) returns Mu
```

ne

### multi sub infix:«<»

```perl6
multi sub infix:«<»(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

<

### multi sub infix:«>»

```perl6
multi sub infix:«>»(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

>

### multi sub infix:«<=»

```perl6
multi sub infix:«<=»(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

<=

### multi sub infix:«>=»

```perl6
multi sub infix:«>=»(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

>=

### multi sub infix:«<»

```perl6
multi sub infix:«<»(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

<

### multi sub infix:«>»

```perl6
multi sub infix:«>»(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

>

### multi sub infix:«<=»

```perl6
multi sub infix:«<=»(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

<=

### multi sub infix:«>=»

```perl6
multi sub infix:«>=»(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

>=

### multi sub infix:«<»

```perl6
multi sub infix:«<»(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

<

### multi sub infix:«>»

```perl6
multi sub infix:«>»(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

>

### multi sub infix:«<=»

```perl6
multi sub infix:«<=»(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

<=

### multi sub infix:«>=»

```perl6
multi sub infix:«>=»(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

>=

### multi sub infix:<lt>

```perl6
multi sub infix:<lt>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

lt

### multi sub infix:<gt>

```perl6
multi sub infix:<gt>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

gt

### multi sub infix:<le>

```perl6
multi sub infix:<le>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

le

### multi sub infix:<ge>

```perl6
multi sub infix:<ge>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

ge

### multi sub infix:<%>

```perl6
multi sub infix:<%>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

%

### multi sub infix:<%%>

```perl6
multi sub infix:<%%>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

%%

### multi sub infix:<~>

```perl6
multi sub infix:<~>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

~

### multi sub prefix:<not>

```perl6
multi sub prefix:<not>(
    Red::AST $a
) returns Mu
```

not X

### multi sub prefix:<!>

```perl6
multi sub prefix:<!>(
    Red::AST::In $a
) returns Mu
```

!X

### multi sub prefix:<so>

```perl6
multi sub prefix:<so>(
    Red::AST $a
) returns Mu
```

so

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

AND

### multi sub infix:<OR>

```perl6
multi sub infix:<OR>(
    Red::AST $a,
    Red::AST $b
) returns Mu
```

OR

### multi sub infix:<∪>

```perl6
multi sub infix:<∪>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

∪

### multi sub infix:<(|)>

```perl6
multi sub infix:<(|)>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

(|)

### multi sub infix:<∩>

```perl6
multi sub infix:<∩>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

∩

### multi sub infix:<(&)>

```perl6
multi sub infix:<(&)>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

(&)

### multi sub infix:<⊖>

```perl6
multi sub infix:<⊖>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

⊖

### multi sub infix:<(-)>

```perl6
multi sub infix:<(-)>(
    Red::ResultSeq $a,
    Red::ResultSeq $b
) returns Mu
```

(-)

### multi sub infix:<in>

```perl6
multi sub infix:<in>(
    Red::AST $a,
    Red::ResultSeq:D $b
) returns Mu
```

in

### multi sub infix:<⊂>

```perl6
multi sub infix:<⊂>(
    Red::AST $a,
    Red::ResultSeq $b
) returns Mu
```

⊂

### multi sub infix:«(<)»

```perl6
multi sub infix:«(<)»(
    Red::AST $a,
    Red::ResultSeq $b
) returns Mu
```

(<)

### multi sub infix:<⊃>

```perl6
multi sub infix:<⊃>(
    Red::AST $a,
    Red::ResultSeq $b
) returns Mu
```

⊃

### multi sub infix:«(>)»

```perl6
multi sub infix:«(>)»(
    Red::AST $a,
    Red::ResultSeq $b
) returns Mu
```

(>)

