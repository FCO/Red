use Red::AST;
use Red::AST::Infixes;
use Red::AST::Divisable;
use Red::AST::Value;
use Red::ResultSeq;

=head2 Red::Operators

unit module Red::Operators;

# TODO: Diferenciate prefix and postfix
#| --X
multi prefix:<-->(Red::Column $a) is export {
    @*UPDATE.push: $a => Red::AST::Sub.new: $a, ast-value 1;
    $a
}

#| ++X
multi prefix:<++>(Red::Column $a) is export {
    @*UPDATE.push: $a => Red::AST::Sum.new: $a, ast-value 1;
    $a
}

#| X--
multi postfix:<-->(Red::Column $a) is export {
    @*UPDATE.push: $a => Red::AST::Sub.new: $a, ast-value 1;
    $a
}

#| X++
multi postfix:<++>(Red::AST $a) is export {
    @*UPDATE.push: $a => Red::AST::Sum.new: $a, ast-value 1;
    $a
}

#| -X
multi prefix:<->(Red::AST $a) is export {
    Red::AST::Mul.new: ast-value(-1), $a
}

#| +X
multi prefix:<+>(Red::AST $a) is export {
    Red::AST::Mul.new: ast-value(1), $a
}

#| X + Y
multi infix:<+>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Sum.new: $a, $b
}

#| X + Y # Where Y is castable to Numeric
multi infix:<+>(Red::AST $a, Numeric() $b) is export {
    Red::AST::Sum.new: $a, ast-value $b
}

#| X + Y # Where X is castable to Numeric
multi infix:<+>(Numeric() $a, Red::AST $b) is export {
    Red::AST::Sum.new: ast-value($a), $b
}

#| X - Y
multi infix:<->(Red::AST $a, Red::AST $b) is export {
    Red::AST::Sub.new: $a, $b
}

#| X - Y # Where Y is castable to Numeric
multi infix:<->(Red::AST $a, Numeric() $b) is export {
    Red::AST::Sub.new: $a, ast-value $b
}

#| X - Y # Where X is castable to Numeric
multi infix:<->(Numeric() $a, Red::AST $b) is export {
    Red::AST::Sub.new: ast-value($a), $b
}

#| X * Y
multi infix:<*>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Mul.new: $a, $b
}

#| X * Y # Where Y is castable to Numeric
multi infix:<*>(Red::AST $a, Numeric() $b) is export {
    Red::AST::Mul.new: $a, ast-value $b
}

#| X * Y
multi infix:<*>(Numeric() $a, Red::AST $b) is export {
    Red::AST::Mul.new: ast-value($a), $b
}

#| X / Y
multi infix:</>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Div.new: $a, $b
}

#| X / Y # Where Y is castable to Numeric and read only
multi infix:</>(Red::AST $a, Numeric() $b is readonly) is export {
    Red::AST::Div.new: $a, ast-value $b
}

#| X / Y # Where X is castable to Numeric and read only
multi infix:</>(Numeric() $a is readonly, Red::AST $b) is export {
    Red::AST::Div.new: ast-value($a), $b
}

#| X / Y # Where Y is castable to Numeric and writable
multi infix:</>(Red::AST $a, Numeric() $b is rw) is export {
    Red::AST::Div.new: $a, ast-value($b), :bind-right
}

#| X / Y # Where X is castable to Numeric and writable
multi infix:</>(Numeric() $a is rw, Red::AST $b) is export {
    Red::AST::Div.new: ast-value($a), $b, :bind-left
}


#| X div Y
multi infix:<div>(Red::AST $a, Red::AST $b) is export {
    Red::AST::IDiv.new: $a, $b
}

#| X div Y # Where Y is castable to Numeric and read only
multi infix:<div>(Red::AST $a, Numeric() $b is readonly) is export {
    Red::AST::IDiv.new: $a, ast-value $b
}

#| X div Y # Where X is castable to Numeric and read only
multi infix:<div>(Numeric() $a is readonly, Red::AST $b) is export {
    Red::AST::IDiv.new: ast-value($a), $b
}

#| X div Y # Where Y is castable to Numeric and writable
multi infix:<div>(Red::AST $a, Numeric() $b is rw) is export {
    Red::AST::IDiv.new: $a, ast-value($b), :bind-right
}

#| X div Y # Where X is castable to Numeric and writable
multi infix:<div>(Numeric() $a is rw, Red::AST $b) is export {
    Red::AST::IDiv.new: ast-value($a), $b, :bind-left
}

#| X == Y
multi infix:<==>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Eq.new: $a, $b, :cast<num>
}

#| X == Y # Where Y is castable to Numeric and writable
multi infix:<==>(Red::AST $a, Numeric() $b is rw) is export {
    Red::AST::Eq.new: $a, ast-value($b), :cast<num>, :bind-right
}

#| X == Y # Where Y is castable to Numeric and read only
multi infix:<==>(Red::AST $a, Numeric() $b is readonly) is export {
    Red::AST::Eq.new: $a, ast-value($b), :cast<num>
}

#| X == Y # Where X is castable to Numeric and writable
multi infix:<==>(Numeric() $a is rw, Red::AST $b) is export {
    Red::AST::Eq.new: ast-value($a), $b, :cast<num>, :bind-left
}

#| X == Y # Where X is castable to Numeric and read only
multi infix:<==>(Numeric() $a is readonly, Red::AST $b) is export {
    Red::AST::Eq.new: ast-value($a), $b, :cast<num>
}

#| X == Y # Where X is castable to Numeric and read only
multi infix:<==>(Red::AST $a where .returns ~~ DateTime, Date $b) is export {
    Red::AST::Eq.new: $a.yyyy-mm-dd, ast-value($b), :cast<num>;
}

#| X != Y # Where Y is castable to Numeric and writable
multi infix:<!=>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Ne.new: $a, $b, :cast<num>
}

#| X != Y # Where Y is castable to Numeric and read only
multi infix:<!=>(Red::AST $a, Numeric() $b is rw) is export {
    Red::AST::Ne.new: $a, ast-value($b), :cast<num>, :bind-right
}

#| X != Y # Where Y is castable to Numeric and read only
multi infix:<!=>(Red::AST $a, Numeric() $b is readonly) is export {
    Red::AST::Ne.new: $a, ast-value($b), :cast<num>
}

#| X != Y # Where X is castable to Numeric and writable
multi infix:<!=>(Numeric() $a is rw, Red::AST $b) is export {
    Red::AST::Ne.new: ast-value($a), $b, :cast<num>, :bind-left
}

#| X != Y # Where X is castable to Numeric and read only
multi infix:<!=>(Numeric() $a is readonly, Red::AST $b) is export {
    Red::AST::Ne.new: ast-value($a), $b, :cast<num>
}

#| X == Y
#multi infix:<==>(Red::AST $a, Red::AST $b) is export {
#    Red::AST::Eq.new: $a, $b, :cast<num>
#}

#| X == Y # Where Y is Date and writable
multi infix:<==>(Red::AST $a, Date $b is rw) is export {
    Red::AST::Eq.new: $a, ast-value($b), :cast<num>, :bind-right
}

#| X == Y # Where Y is Date and read only
multi infix:<==>(Red::AST $a, Date $b is readonly) is export {
    Red::AST::Eq.new: $a, ast-value($b), :cast<num>
}

#| X == Y # Where X is Date and writable
multi infix:<==>(Date $a is rw, Red::AST $b) is export {
    Red::AST::Eq.new: ast-value($a), $b, :cast<num>, :bind-left
}

#| X == Y # Where X is Date and read only
multi infix:<==>(Date $a is readonly, Red::AST $b) is export {
    Red::AST::Eq.new: ast-value($a), $b, :cast<num>
}

#| X != Y
multi infix:<!=>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Ne.new: $a, $b, :cast<num>
}

#| X != Y # Where Y is Date and writable
multi infix:<!=>(Red::AST $a, Date $b is rw) is export {
    Red::AST::Ne.new: $a, ast-value($b), :cast<num>, :bind-right
}

#| X != Y # Where Y is Date and read only
multi infix:<!=>(Red::AST $a, Date $b is readonly) is export {
    Red::AST::Ne.new: $a, ast-value($b), :cast<num>
}

#| X != Y # Where X is Date and writable
multi infix:<!=>(Date $a is rw, Red::AST $b) is export {
    Red::AST::Ne.new: ast-value($a), $b, :cast<num>, :bind-left
}

#| X != Y # Where X is Date and read only
multi infix:<!=>(Date $a is readonly, Red::AST $b) is export {
    Red::AST::Ne.new: ast-value($a), $b, :cast<num>
}

#| X eq Y # Where Y is castable to Str and writable
multi infix:<eq>(Red::AST $a, Str() $b is rw) is export {
    Red::AST::Eq.new: $a, ast-value($b), :cast<str>, :bind-right
}

#| X eq Y # Where Y is castable to Str and read only
multi infix:<eq>(Red::AST $a, Str() $b is readonly) is export {
    Red::AST::Eq.new: $a, ast-value($b), :cast<str>
}

#| X eq Y # Where X is castable to Str and writable
multi infix:<eq>(Str() $a is rw, Red::AST $b) is export {
    Red::AST::Eq.new: ast-value($a), $b, :cast<str>, :bind-left
}

#| X eq Y # Where X is castable to Str and read only
multi infix:<eq>(Str() $a is readonly, Red::AST $b) is export {
    Red::AST::Eq.new: ast-value($a), $b, :cast<str>
}

#| X eq Y # Where Y is any Red::AST that returns a DateTime
multi infix:<eq>(Red::AST $a where .returns ~~ DateTime, Date $b) is export {
    Red::AST::Eq.new: $a.yyyy-mm-dd, ast-value($b), :cast<str>;
}

#| X ne Y # Where Y is castable to Str and writable
multi infix:<ne>(Red::AST $a, Str() $b is rw) is export {
    Red::AST::Ne.new: $a, ast-value($b), :cast<str>, :bind-right
}

#| X ne Y # Where Y is castable to Str and read only
multi infix:<ne>(Red::AST $a, Str() $b is readonly) is export {
    Red::AST::Ne.new: $a, ast-value($b), :cast<str>
}

#| X ne Y # Where X is castable to Str and writable
multi infix:<ne>(Str() $a is rw, Red::AST $b) is export {
    Red::AST::Ne.new: ast-value($a), $b, :cast<str>, :bind-left
}

#| X ne Y # Where X is castable to Str and read only
multi infix:<ne>(Str() $a is readonly, Red::AST $b) is export {
    Red::AST::Ne.new: ast-value($a), $b, :cast<str>
}

#| X < Y # Where Y is any Red::AST that returns a DateTime
multi infix:<< < >>(Red::AST $a where .returns ~~ Numeric, Red::AST $b) is export {
    Red::AST::Lt.new: $a, $b, :cast<num>
}

#| X < Y # Where Y is castable to Numeric and writable
multi infix:<< < >>(Red::AST $a, Numeric() $b is rw) is export {
    Red::AST::Lt.new: $a, ast-value($b), :cast<num>, :bind-right
}

#| X < Y # Where Y is castable to Numeric and read only
multi infix:<< < >>(Red::AST $a, Numeric() $b is readonly) is export {
    Red::AST::Lt.new: $a, ast-value($b), :cast<num>
}

#| X < Y # Where X is castable to Numeric and writable
multi infix:<< < >>(Numeric() $a is rw, Red::AST $b) is export {
    Red::AST::Lt.new: ast-value($a), $b, :cast<num>, :bind-left
}

#| X < Y # Where X is castable to Numeric and read only
multi infix:<< < >>(Numeric() $a is readonly, Red::AST $b) is export {
    Red::AST::Lt.new: ast-value($a), $b, :cast<num>
}

#| X > Y # Where Y is any Red::AST that returns a Numeric
multi infix:<< > >>(Red::AST $a where .returns ~~ Numeric, Red::AST $b) is export {
    Red::AST::Gt.new: $a, $b, :cast<num>
}

#| X > Y # Where Y is castable to Numeric and writable
multi infix:<< > >>(Red::AST $a, Numeric() $b is rw) is export {
    Red::AST::Gt.new: $a, ast-value($b), :cast<num>, :bind-right
}

#| X > Y # Where Y is castable to Numeric and read only
multi infix:<< > >>(Red::AST $a, Numeric() $b is readonly) is export {
    Red::AST::Gt.new: $a, ast-value($b), :cast<num>
}

#| X > Y # Where X is castable to Numeric and writable
multi infix:<< > >>(Numeric() $a is rw, Red::AST $b) is export {
    Red::AST::Gt.new: ast-value($a), $b, :cast<num>, :bind-left
}

#| X > Y # Where X is castable to Numeric and read only
multi infix:<< > >>(Numeric() $a is readonly, Red::AST $b) is export {
    Red::AST::Gt.new: ast-value($a), $b, :cast<num>
}

#| X <= Y # Where Y is any Red::AST that returns a Numeric
multi infix:<< <= >>(Red::AST $a where .returns ~~ Numeric, Red::AST $b) is export {
    Red::AST::Le.new: $a, $b, :cast<num>
}

#| X <= Y # Where Y is castable to Numeric and read only
multi infix:<< <= >>(Red::AST $a, Numeric() $b is rw) is export {
    Red::AST::Le.new: $a, ast-value($b), :cast<num>, :bind-right
}

#| X <= Y # Where Y is castable to Numeric and read only
multi infix:<< <= >>(Red::AST $a, Numeric() $b is readonly) is export {
    Red::AST::Le.new: $a, ast-value($b), :cast<num>
}

#| X <= Y # Where X is castable to Numeric and writable
multi infix:<< <= >>(Numeric() $a is rw, Red::AST $b) is export {
    Red::AST::Le.new: ast-value($a), $b, :cast<num>, :bind-left
}

#| X <= Y # Where X is castable to Numeric and read only
multi infix:<< <= >>(Numeric() $a is readonly, Red::AST $b) is export {
    Red::AST::Le.new: ast-value($a), $b, :cast<num>
}

#| X >= Y # Where Y is any Red::AST that returns a DateTime
multi infix:<< >= >>(Red::AST $a where .returns ~~ Numeric, Red::AST $b) is export {
    Red::AST::Ge.new: $a, $b, :cast<num>
}

#| X >= Y # Where Y is castable to Numeric and writable
multi infix:<< >= >>(Red::AST $a, Numeric() $b is rw) is export {
    Red::AST::Ge.new: $a, ast-value($b), :cast<num>, :bind-right
}

#| X >= Y # Where Y is castable to Numeric and read only
multi infix:<< >= >>(Red::AST $a, Numeric() $b is readonly) is export {
    Red::AST::Ge.new: $a, ast-value($b), :cast<num>
}

#| X >= Y # Where X is castable to Numeric and writable
multi infix:<< >= >>(Numeric() $a is rw, Red::AST $b) is export {
    Red::AST::Ge.new: ast-value($a), $b, :cast<num>, :bind-left
}

#| X >= Y # Where X is castable to Numeric and read only
multi infix:<< >= >>(Numeric() $a is readonly, Red::AST $b) is export {
    Red::AST::Ge.new: ast-value($a), $b, :cast<num>
}

############################
#| X < Y # Where Y is any Red::AST that returns a DateTime
multi infix:<< < >>(Red::AST $a where .returns ~~ DateTime, Red::AST $b) is export {
    Red::AST::Lt.new: $a, $b, :cast<num>
}

#| X < Y # Where Y is DateTime and writable
multi infix:<< < >>(Red::AST $a, DateTime $b is rw) is export {
    Red::AST::Lt.new: $a, ast-value($b), :cast<num>, :bind-right
}

#| X < Y # Where Y is DateTime and read only
multi infix:<< < >>(Red::AST $a, DateTime $b is readonly) is export {
    Red::AST::Lt.new: $a, ast-value($b), :cast<num>
}

#| X < Y # Where X is DateTime and writable
multi infix:<< < >>(DateTime $a is rw, Red::AST $b) is export {
    Red::AST::Lt.new: ast-value($a), $b, :cast<num>, :bind-left
}

#| X < Y # Where X is DateTime and read only
multi infix:<< < >>(DateTime $a is readonly, Red::AST $b) is export {
    Red::AST::Lt.new: ast-value($a), $b, :cast<num>
}

#| X > Y # Where Y is any Red::AST that returns a DateTime
multi infix:<< > >>(Red::AST $a where .returns ~~ DateTime, Red::AST $b) is export {
    Red::AST::Gt.new: $a, $b, :cast<num>
}

#| X > Y # Where Y is DateTime and writable
multi infix:<< > >>(Red::AST $a, DateTime $b is rw) is export {
    Red::AST::Gt.new: $a, ast-value($b), :cast<num>, :bind-right
}

#| X > Y # Where Y is DateTime and read only
multi infix:<< > >>(Red::AST $a, DateTime $b is readonly) is export {
    Red::AST::Gt.new: $a, ast-value($b), :cast<num>
}

#| X > Y # Where X is DateTime and writable
multi infix:<< > >>(DateTime $a is rw, Red::AST $b) is export {
    Red::AST::Gt.new: ast-value($a), $b, :cast<num>, :bind-left
}

#| X > Y # Where X is DateTime and read only
multi infix:<< > >>(DateTime $a is readonly, Red::AST $b) is export {
    Red::AST::Gt.new: ast-value($a), $b, :cast<num>
}

#| X <= Y # Where Y is any Red::AST that returns a DateTime
multi infix:<< <= >>(Red::AST $a where .returns ~~ DateTime, Red::AST $b) is export {
    Red::AST::Le.new: $a, $b, :cast<num>
}

#| X <= Y # Where Y is DateTime and writable
multi infix:<< <= >>(Red::AST $a, DateTime $b is rw) is export {
    Red::AST::Le.new: $a, ast-value($b), :cast<num>, :bind-right
}

#| X <= Y # Where Y is DateTime and read only
multi infix:<< <= >>(Red::AST $a, DateTime $b is readonly) is export {
    Red::AST::Le.new: $a, ast-value($b), :cast<num>
}

#| X <= Y # Where X is DateTime and writable
multi infix:<< <= >>(DateTime $a is rw, Red::AST $b) is export {
    Red::AST::Le.new: ast-value($a), $b, :cast<num>, :bind-left
}

#| X <= Y # Where X is DateTime and read only
multi infix:<< <= >>(DateTime $a is readonly, Red::AST $b) is export {
    Red::AST::Le.new: ast-value($a), $b, :cast<num>
}

#| X >= Y # Where Y is any Red::AST that returns a DateTime
multi infix:<< >= >>(Red::AST $a where .returns ~~ DateTime, Red::AST $b) is export {
    Red::AST::Ge.new: $a, $b, :cast<num>
}

#| X >= Y # Where Y is DateTime and writable
multi infix:<< >= >>(Red::AST $a, DateTime $b is rw) is export {
    Red::AST::Ge.new: $a, ast-value($b), :cast<num>, :bind-right
}

#| X >= Y # Where Y is DateTime and read only
multi infix:<< >= >>(Red::AST $a, DateTime $b is readonly) is export {
    Red::AST::Ge.new: $a, ast-value($b), :cast<num>
}

#| X >= Y # Where X is DateTime and writable
multi infix:<< >= >>(DateTime $a is rw, Red::AST $b) is export {
    Red::AST::Ge.new: ast-value($a), $b, :cast<num>, :bind-left
}

#| X >= Y # Where X is DateTime and read only
multi infix:<< >= >>(DateTime $a is readonly, Red::AST $b) is export {
    Red::AST::Ge.new: ast-value($a), $b, :cast<num>
}

############################

#| X < Y # Where Y is any Red::AST that returns a Date
multi infix:<< < >>(Red::AST $a where .returns ~~ Date, Red::AST $b) is export {
    Red::AST::Lt.new: $a, $b, :cast<num>
}

#| X < Y # Where Y is Date and writable
multi infix:<< < >>(Red::AST $a, Date $b is rw) is export {
    Red::AST::Lt.new: $a, ast-value($b), :cast<num>, :bind-right
}

#| X < Y # Where Y is Date and read only
multi infix:<< < >>(Red::AST $a, Date $b is readonly) is export {
    Red::AST::Lt.new: $a, ast-value($b), :cast<num>
}

#| X < Y # Where X is Date and writable
multi infix:<< < >>(Date $a is rw, Red::AST $b) is export {
    Red::AST::Lt.new: ast-value($a), $b, :cast<num>, :bind-left
}

#| X < Y # Where X is Date and read only
multi infix:<< < >>(Date $a is readonly, Red::AST $b) is export {
    Red::AST::Lt.new: ast-value($a), $b, :cast<num>
}

#| X > Y # Where Y is any Red::AST that returns a Date
multi infix:<< > >>(Red::AST $a where .returns ~~ Date, Red::AST $b) is export {
    Red::AST::Gt.new: $a, $b, :cast<num>
}

#| X > Y # Where Y is Date and writable
multi infix:<< > >>(Red::AST $a, Date $b is rw) is export {
    Red::AST::Gt.new: $a, ast-value($b), :cast<num>, :bind-right
}

#| X > Y # Where Y is Date and read only
multi infix:<< > >>(Red::AST $a, Date $b is readonly) is export {
    Red::AST::Gt.new: $a, ast-value($b), :cast<num>
}

#| X > Y # Where X is Date and writable
multi infix:<< > >>(Date $a is rw, Red::AST $b) is export {
    Red::AST::Gt.new: ast-value($a), $b, :cast<num>, :bind-left
}

#| X > Y # Where X is Date and read only
multi infix:<< > >>(Date $a is readonly, Red::AST $b) is export {
    Red::AST::Gt.new: ast-value($a), $b, :cast<num>
}

#| X <= Y # Where Y is any Red::AST that returns a Date
multi infix:<< <= >>(Red::AST $a where .returns ~~ Date, Red::AST $b) is export {
    Red::AST::Le.new: $a, $b, :cast<num>
}

#| X <= Y # Where Y is Date and writable
multi infix:<< <= >>(Red::AST $a, Date $b is rw) is export {
    Red::AST::Le.new: $a, ast-value($b), :cast<num>, :bind-right
}

#| X <= Y # Where Y is Date and read only
multi infix:<< <= >>(Red::AST $a, Date $b is readonly) is export {
    Red::AST::Le.new: $a, ast-value($b), :cast<num>
}

#| X <= Y # Where X is Date and read only
multi infix:<< <= >>(Date $a is rw, Red::AST $b) is export {
    Red::AST::Le.new: ast-value($a), $b, :cast<num>, :bind-left
}

#| X <= Y # Where X is Date and read only
multi infix:<< <= >>(Date $a is readonly, Red::AST $b) is export {
    Red::AST::Le.new: ast-value($a), $b, :cast<num>
}

#| X >= Y # Where Y is any Red::AST that returns a Date
multi infix:<< >= >>(Red::AST $a where .returns ~~ Date, Red::AST $b) is export {
    Red::AST::Ge.new: $a, $b, :cast<num>
}

#| X >= Y # Where Y is Date and writable
multi infix:<< >= >>(Red::AST $a, Date $b is rw) is export {
    Red::AST::Ge.new: $a, ast-value($b), :cast<num>, :bind-right
}

#| X >= Y # Where Y is Date and read only
multi infix:<< >= >>(Red::AST $a, Date $b is readonly) is export {
    Red::AST::Ge.new: $a, ast-value($b), :cast<num>
}

#| X >= Y # Where X is Date and writable
multi infix:<< >= >>(Date $a is rw, Red::AST $b) is export {
    Red::AST::Ge.new: ast-value($a), $b, :cast<num>, :bind-left
}

#| X >= Y # Where X is Date and read only
multi infix:<< >= >>(Date $a is readonly, Red::AST $b) is export {
    Red::AST::Ge.new: ast-value($a), $b, :cast<num>
}

#| X lt Y
multi infix:<lt>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Lt.new: $a, $b, :cast<str>
}

#| X lt Y # Where Y is castable to Str and writable
multi infix:<lt>(Red::AST $a, Str() $b is rw) is export {
    Red::AST::Lt.new: $a, ast-value($b), :cast<str>, :bind-right
}

#| X lt Y # Where Y is castable to Str and read only
multi infix:<lt>(Red::AST $a, Str() $b is readonly) is export {
    Red::AST::Lt.new: $a, ast-value($b), :cast<str>
}

#| X lt Y # Where X is castable to Str and writable
multi infix:<lt>(Str() $a is rw, Red::AST $b) is export {
    Red::AST::Lt.new: ast-value($a), $b, :cast<str>, :bind-left
}

#| X lt Y # Where X is castable to Str and read only
multi infix:<lt>(Str() $a is readonly, Red::AST $b) is export {
    Red::AST::Lt.new: ast-value($a), $b, :cast<str>
}

#| X gt Y
multi infix:<gt>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Gt.new: $a, $b, :cast<str>
}

#| X gt Y # Where Y is castable to Str and writable
multi infix:<gt>(Red::AST $a, Str() $b is rw) is export {
    Red::AST::Gt.new: $a, ast-value($b), :cast<str>, :bind-right
}

#| X gt Y # Where Y is castable to Str and read only
multi infix:<gt>(Red::AST $a, Str() $b is readonly) is export {
    Red::AST::Gt.new: $a, ast-value($b), :cast<str>
}

#| X gt Y # Where X is castable to Str and writable
multi infix:<gt>(Str() $a is rw, Red::AST $b) is export {
    Red::AST::Gt.new: ast-value($a), $b, :cast<str>, :bind-left
}

#| X gt Y # Where X is castable to Str and read only
multi infix:<gt>(Str() $a is readonly, Red::AST $b) is export {
    Red::AST::Gt.new: ast-value($a), $b, :cast<str>
}

#| X le Y
multi infix:<le>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Le.new: $a, $b, :cast<str>
}

#| X le Y # Where Y is castable to Str and writable
multi infix:<le>(Red::AST $a, Str() $b is rw) is export {
    Red::AST::Le.new: $a, ast-value($b), :cast<str>, :bind-right
}

#| X le Y # Where Y is castable to Str and read only
multi infix:<le>(Red::AST $a, Str() $b is readonly) is export {
    Red::AST::Le.new: $a, ast-value($b), :cast<str>
}

#| X le Y # Where X is castable to Str and writable
multi infix:<le>(Str() $a is rw, Red::AST $b) is export {
    Red::AST::Le.new: ast-value($a), $b, :cast<str>, :bind-left
}

#| X le Y # Where X is castable to Str and read only
multi infix:<le>(Str() $a is readonly, Red::AST $b) is export {
    Red::AST::Le.new: ast-value($a), $b, :cast<str>
}

#| X ge Y
multi infix:<ge>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Ge.new: $a, $b, :cast<str>
}

#| X ge Y # Where Y is castable to Str and writable
multi infix:<ge>(Red::AST $a, Str() $b is rw) is export {
    Red::AST::Ge.new: $a, ast-value($b), :cast<str>, :bind-right
}

#| X ge Y # Where Y is castable to Str and read only
multi infix:<ge>(Red::AST $a, Str() $b is readonly) is export {
    Red::AST::Ge.new: $a, ast-value($b), :cast<str>
}

#| X ge Y # Where X is castable to Str and writable
multi infix:<ge>(Str() $a is rw, Red::AST $b) is export {
    Red::AST::Ge.new: ast-value($a), $b, :cast<str>, :bind-left
}

#| X ge Y # Where X is castable to Str and read only
multi infix:<ge>(Str() $a is readonly, Red::AST $b) is export {
    Red::AST::Ge.new: ast-value($a), $b, :cast<str>
}

#| X % Y
multi infix:<%>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Mod.new: $a, $b, :cast<int>
}

#| X % Y # Where X is castable to Int and writable
multi infix:<%>(Red::AST $a, Int() $b is rw) is export {
    Red::AST::Mod.new: $a, ast-value($b), :cast<int>, :bind-right
}

#| X % Y # Where Y is castable to Int and read only
multi infix:<%>(Red::AST $a, Int() $b is readonly) is export {
    Red::AST::Mod.new: $a, ast-value($b), :cast<int>
}

#| X % Y # Where X is castable to Int and writable
multi infix:<%>(Int() $a is rw, Red::AST $b) is export {
    Red::AST::Mod.new: ast-value($a), $b, :cast<int>, :bind-left
}

#| X % Y # Where X is castable to Int and read only
multi infix:<%>(Int() $a is readonly, Red::AST $b) is export {
    Red::AST::Mod.new: ast-value($a), $b, :cast<int>
}

#| X %% Y
multi infix:<%%>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Divisable.new: $a, $b, :cast<int>
}

#| X %% Y # Where Y is castable to Int and writable
multi infix:<%%>(Red::AST $a, Int() $b is rw) is export {
    Red::AST::Divisable.new: $a, ast-value($b), :cast<int>, :bind-right
}

#| X %% Y # Where Y is castable to Int and read only
multi infix:<%%>(Red::AST $a, Int() $b is readonly) is export {
    Red::AST::Divisable.new: $a, ast-value($b), :cast<int>
}

#| X %% Y # Where X is castable to Int
multi infix:<%%>(Int() $a is rw, Red::AST $b) is export {
    Red::AST::Divisable.new: ast-value($a), $b, :cast<int>, :bind-left
}

#| X %% Y # Where X is read only
multi infix:<%%>(Int() $a is readonly, Red::AST $b) is export {
    Red::AST::Divisable.new: ast-value($a), $b, :cast<int>
}

#| X ~ Y
multi infix:<~>(Red::AST $a, Red::AST $b) is export {
    Red::AST::Concat.new: $a, $b, :cast<str>
}

#| X ~ Y Where Y is castable to Str and writable
multi infix:<~>(Red::AST $a, Str() $b is rw) is export {
    Red::AST::Concat.new: $a, ast-value($b), :cast<str>, :bind-right
}

#| X ~ Y Where Y is castable to Str and read only
multi infix:<~>(Red::AST $a, Str() $b is readonly) is export {
    Red::AST::Concat.new: $a, ast-value($b), :cast<str>
}

#| X ~ Y # Where X is castable to Str and writable
multi infix:<~>(Str() $a is rw, Red::AST $b) is export {
    Red::AST::Concat.new: ast-value($a), $b, :cast<str>, :bind-left
}

#| X ~ Y # Where X is castable to Str and read only
multi infix:<~>(Str() $a is readonly, Red::AST $b) is export {
    Red::AST::Concat.new: ast-value($a), $b, :cast<str>
}

#| not X # Where X is read only
multi prefix:<not>(Red::AST $a is readonly) is export {
    Red::AST::Not.new: $a
}

#| not X
multi prefix:<not>(Red::AST $a is rw) is export {
    Red::AST::Not.new: $a, :bind
}

#| !X
multi prefix:<!>(Red::AST $a) is export {
    Red::AST::Not.new: $a
}

#| not X # Where X is a in
multi prefix:<not>(Red::AST::In $a) is export {
    $a.not;
}

#| !X # Where X is a in
multi prefix:<!>(Red::AST::In $a) is export {
    $a.not;
}

#| so X
multi prefix:<so>(Red::AST $a) is export {
    Red::AST::So.new: $a
}

#| ?X
multi prefix:<?>(Red::AST $a) is export {
    Red::AST::So.new: $a
}

#| X AND Y
multi infix:<AND>(Red::AST $a, Red::AST $b) is export is tighter(&infix:<==>) {
    Red::AST::AND.new: $a, $b
}

#| X OR Y
multi infix:<OR>(Red::AST $a, Red::AST $b) is export {
    Red::AST::OR.new: $a, $b
}

#| X ∪ Y # Where X and Y are ResultSeqs
multi infix:<∪>(Red::ResultSeq $a, Red::ResultSeq $b) is export {
    $a (|) $b
}
#| X (|) Y # Where X and Y are ResultSeqs
multi infix:<(|)>(Red::ResultSeq $a, Red::ResultSeq $b) is export {
    $a.union: $b
}
#| X ∩ Y # Where X and Y are ResultSeqs
multi infix:<∩>(Red::ResultSeq $a, Red::ResultSeq $b) is export {
    $a (&) $b
}
#| X (&) Y # Where X and Y are ResultSeqs
multi infix:<(&)>(Red::ResultSeq $a, Red::ResultSeq $b) is export {
    $a.intersect: $b
}
#| X ⊖ Y # Where X and Y are ResultSeqs
multi infix:<⊖>(Red::ResultSeq $a, Red::ResultSeq $b) is export {
    $a (-) $b
}
#| X (-) Y # Where X and Y are ResultSeqs
multi infix:<(-)>(Red::ResultSeq $a, Red::ResultSeq $b) is export {
    $a.minus: $b
}

#| X in Y # Where Y is a ResultSeq
multi infix:<in>(Red::AST $a, Red::ResultSeq:D $b ) is export is default {
    Red::AST::In.new: $a, $b.ast(:sub-select);
}
#| X ⊂ Y # Where Y is a ResultSeq
multi infix:<⊂>(Red::AST $a, Red::ResultSeq $b ) is export is default {
    Red::AST::In.new: $a, $b.ast(:sub-select);
}
#| X (<) Y # Where Y is a ResultSeq
multi infix:«(<)»(Red::AST $a, Red::ResultSeq $b ) is export is default {
    Red::AST::In.new: $a, $b.ast(:sub-select);
}
#| X ⊃ Y # Where Y is a ResultSeq
multi infix:<⊃>(Red::AST $a, Red::ResultSeq $b ) is export is default {
    Red::AST::NotIn.new: $a, $b.ast(:sub-select);
}
#| X (>) Y # Where Y is a ResultSeq
multi infix:«(>)»(Red::AST $a, Red::ResultSeq $b ) is export is default {
    Red::AST::NotIn.new: $a, $b.ast(:sub-select);
}

subset PositionalNotResultSeq of Any  where { $_ ~~ Positional && $_ !~~ Red::ResultSeq };

#| X in Y # Where Y is a positional but not a ResultSeq
multi infix:<in>(Red::AST $a, PositionalNotResultSeq $b ) is export {
    Red::AST::In.new: $a, ast-value($b);
}

#| X ⊂ Y # Where Y is a positional but not a ResultSeq
multi infix:<⊂>(Red::AST $a, PositionalNotResultSeq $b ) is export {
    Red::AST::In.new: $a, ast-value($b);
}

#| X (<) Y # Where Y is a positional but not a ResultSeq
multi infix:«(<)»(Red::AST $a, PositionalNotResultSeq $b ) is export {
    Red::AST::In.new: $a, ast-value($b);
}

#| X ⊃ Y # Where Y is a positional but not a ResultSeq
multi infix:<⊃>(Red::AST $a, PositionalNotResultSeq $b ) is export {
    Red::AST::NotIn.new: $a, ast-value($b);
}

#| X (>) Y # Where Y is a positional but not a ResultSeq
multi infix:«(>)»(Red::AST $a, PositionalNotResultSeq $b ) is export {
    Red::AST::NotIn.new: $a, ast-value($b);
}

#| X in Y # where Y is a select
multi infix:<in>(Red::AST $a, Red::AST::Select $b ) is export {
    Red::AST::In.new: $a, $b.as-sub-select;
}

#| X ⊂ Y # where Y is a select
multi infix:<⊂>(Red::AST $a, Red::AST::Select $b ) is export {
    Red::AST::In.new: $a, $b.as-sub-select;
}

#| X (<) Y # where Y is a select
multi infix:«(<)»(Red::AST $a, Red::AST::Select $b ) is export {
    Red::AST::In.new: $a, $b.as-sub-select;
}

#| X ⊃ Y # where Y is a select
multi infix:<⊃>(Red::AST $a, Red::AST::Select $b ) is export {
    Red::AST::NotIn.new: $a, $b.as-sub-select;
}

#| X (>) Y # Where Y is a select
multi infix:«(>)»(Red::AST $a, Red::AST::Select $b ) is export {
    Red::AST::NotIn.new: $a, $b.as-sub-select;
}

