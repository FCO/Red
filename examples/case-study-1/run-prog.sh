#!/bin/bash
E="perl6 -I../../lib"
if [[ -z $1 ]] ; then
    echo "Usage: $0 <Perl 6 prog>"
    echo
    echo "Runs '$E' on the input program"
    exit
fi

$E $@

