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

=begin comment

Some queries:

    1. alphabetical list of all contacts by last name, first name, and
       include all known emails in alpha order
    2. number of attendees per year
    3. number of presenters per year
    4. for a person (key), what years was the person an attendee or a presenter
    5. a list of all known valid emails for upload to a mail server
    6. list contacts with their keys

=end comment

my $usage = "Usage: $*PROGRAM <query number> [help | debug]";
if !@*ARGS {
    say $usage;
    exit;
}

my $debug = 0;
for @*ARGS {
    when /^ :i h / {
        help; # program exits from sub
    }
    # queries by number
    when /^ :i d / {
        $debug = 1;
    }
    when /^ 1 $/ { query1 }
    when /^ 2 $/ { query2 }
    when /^ 3 $/ { query3 }
    when /^ 4 $/ { query4 }
    when /^ 5 $/ { query5 }
    when /^ 6 $/ { query6 }
    default {
        die "FATAL: Unknown arg '$_'";
    }
}


##### SUBROUTINES #####
sub query1 {
    # 1. alphabetical list of all contacts by last name, first name, and
    #    include all known emails in alpha order
}

sub query2 {
    # 2. number of attendees per year
}

sub query3 {
    # 3. number of presenters per year
}

sub query4 {
    # 4. for a person (key), what years was the person an attendee or a presenter
    my $pkey = prompt "Enter person key (see query 6): ";
}

sub query5 {
    # 5. a list of all known valid emails for upload to a mail server
}

sub query6 {
    # 6. list contacts with their keys
}

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
