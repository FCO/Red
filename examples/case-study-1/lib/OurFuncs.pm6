unit module OurFuncs;

constant $TEST   is export = 1;
constant $SEMI   is export = ';';
constant $AMP    is export = '&';
constant $COMMA  is export = ',';
constant $UPDATE is export = 1;
constant $NOCHG  is export = 0;

sub handle-error($err) is export {

    return $UPDATE if !$err;
    if $err ~~ /table \s+ \S+ \s+ already \s+ exists / {
        return $NOCHG; # okay, no update made
    }
    else {
        say "Caught error '$err'";
    }
}

sub create-csv-key(:$last   is copy = '',
                   :$first  is copy = '',
                   :%e-mail,
                   :$debug) is export {
    # ensure no ampersand in the first name
    if $first && $first ~~ /'&'/ {
        die "FATAL: illegal ampersand in first name: '$first'";
    }

    # make empty last name sort to the top
    $last = 0 if !$last;

    my $key = "|$last|$first|";
    # add any emails
    for %e-mail.keys.sort -> $e {
        $key ~= "$e|";
    }

    # make all fields lower-case
    $key .= lc;
    # trim all whitespace
    $key ~~ s:g/\s+//;

    return $key;
}
