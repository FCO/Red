#!/usr/bin/env perl6

use Red;

use lib $*PROGRAM.parent.add('lib');
use OurFuncs;
# the Red models
use Present;
use Attend;
use Email;
use Person;

my $dbf = $*PROGRAM.parent.add('data/ctech.sqlite').absolute;

multi MAIN(Int $number, Bool :$*debug!) {
    MAIN $number
}

#| 1. Alphabetical list of all contacts by last name, first name, and
#| include all known emails in alpha order
multi MAIN(1) {
}

#| 2. Number of attendees per year
multi MAIN(2) {
}

#| 3. Number of presenters per year
multi MAIN(3) {
}

#| 4. For a person (id), what years was the person an attendee or a
#| presenter
multi MAIN(4) {
    my $pkey = prompt "Enter person key (see query 6): ";
}

#| 5. A list of all known valid emails for upload to a mail server
multi MAIN(5) {
}

#| 6. List contacts with their ids
multi MAIN(6) {
}


=begin comment
sub help() {
    say qq:to/HERE/;
    $usage

    Queries:

    1. alphabetical list of all contacts by last name, first name, and
       include all known emails in alpha order
    2. number of attendees per year
    3. number of presenters per year
    4. for a person (key), what years was the person an attendee or a presenter
    5. a list of all known valid emails for upload to a mail server
    6. list contacts as in 1 but show key for other queries

    HERE
    exit;
}
=end comment
