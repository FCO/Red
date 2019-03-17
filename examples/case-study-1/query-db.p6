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
    my $q = Person.^all.grep(i  


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
