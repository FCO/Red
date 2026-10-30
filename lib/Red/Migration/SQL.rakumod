use X::Red::Migration;
unit module Red::Migration::SQL;

# Split statements rather than lines. Stored programs require a database-aware
# execution protocol and are rejected until that protocol is implemented.
sub statements(Str $source, Str :$dialect = 'SQL' --> Array) is export {
    my @out;
    my $buffer = '';
    my $quote = '';
    my $dollar = '';
    my $depth = 0;
    my $line-comment = False;
    my $i = 0;
    while $i < $source.chars {
        my $c = $source.substr($i, 1);
        my $pair = $source.substr($i, 2);
        if $line-comment {
            $line-comment = False if $c eq "\n";
            $buffer ~= "\n" if $c eq "\n";
        } elsif $depth {
            if $pair eq '/*' { $depth++; $i++ }
            elsif $pair eq '*/' { $depth--; $i++ }
        } elsif $dollar {
            if $source.substr($i).starts-with($dollar) {
                $buffer ~= $dollar;
                $i += $dollar.chars - 1;
                $dollar = '';
            } else { $buffer ~= $c }
        } elsif $quote {
            $buffer ~= $c;
            if $c eq $quote {
                if $source.substr($i + 1, 1) eq $quote {
                    $buffer ~= $quote; $i++;
                } else { $quote = '' }
            } elsif $c eq '\\' {
                X::Red::Migration.new(:reason('Backslash SQL string escapes are ambiguous; use doubled quotes')).throw;
            }
        } elsif ($pair eq '--' && ($dialect ne 'MySQL'
                || $source.substr($i + 2, 1) eq ''
                || $source.substr($i + 2, 1) ~~ /\s/))
                || ($dialect eq 'MySQL' && $c eq '#') {
            $line-comment = True;
            $buffer ~= ' ';
        } elsif $pair eq '/*' {
            X::Red::Migration.new(:reason('MySQL executable comments are unsupported')).throw
                if $source.substr($i + 2, 1) eq '!'
                    || ($dialect eq 'MySQL' && $source.substr($i + 2, 1) eq '+');
            $depth = 1; $i++; $buffer ~= ' ';
        } elsif $c eq any("'", '"', '`') {
            $quote = $c; $buffer ~= $c;
        } elsif $c eq '$' && $source.substr($i) ~~ /^ ('$' <[A..Za..z_0..9]>* '$') / {
            $dollar = ~$0; $buffer ~= $dollar; $i += $dollar.chars - 1;
        } elsif $c eq ';' {
            @out.push($buffer.trim) if $buffer.trim.chars;
            $buffer = '';
        } else { $buffer ~= $c }
        $i++;
    }
    X::Red::Migration.new(:reason('Unterminated SQL quote or comment')).throw
        if $quote || $dollar || $depth;
    @out.push($buffer.trim) if $buffer.trim.chars;
    for @out -> $sql {
        X::Red::Migration.new(:reason('Stored programs, transaction control and client directives are unsupported')).throw
            if $sql.uc ~~ /^ [BEGIN|START|END|COMMIT|ROLLBACK|SAVEPOINT|RELEASE|DELIMITER|COPY|SOURCE|VACUUM|ATTACH|DETACH|PRAGMA|LOCK|UNLOCK] <|w> /
                || $sql.uc ~~ /^ CREATE \s+ [OR \s+ REPLACE \s+]? [FUNCTION|PROCEDURE|TRIGGER|EVENT] <|w> /
                || $sql.starts-with('\\');
    }
    @out.Array
}
