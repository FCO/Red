#!/usr/bin/env perl6

use Red;

use lib $*PROGRAM.parent.add('lib');
use OurFuncs;
# the Red models
use Present;
use Attend;
use Email;
use Person;

my $dbf = $*PROGRAM.parent.add($DBF).absolute;

my $*RED-DEBUG = 1;
my $*RED-DB = database "SQLite", :database($dbf);

#my $date = DateTime.new(now);
my $date = Date.new(now);
our @*ofils;

multi MAIN(Int $number, Bool :$*debug!) {
    my @ofils;
    MAIN $number;

    write-closer(@*ofils);

}


# IMPORTANT: Querys numbers, title, and content should be as stable as possible
# for ease of repeated use.

# TODO - improved long-term query persistence

#| 1. Alphabetical list of all contacts by last name, first name, and
#| include all known emails in alpha order
multi MAIN(1) {
    my $qnum = 1; # MUST match constant sub arg
    my $title = "TBD";
    my $of = "{$date}-{$title}-query-{$qnum}.csv";
    say "Query $qnum is NYI";
}

#| 2. Number of attendees per year
multi MAIN(2) {
    my $qnum = 2; # MUST match constant sub arg
    my $title = "TBD";
    my $of = "{$date}-{$title}-query-{$qnum}.csv";
    say "Query $qnum is NYI";
}

#| 3. Number of presenters per year
multi MAIN(3) {
    my $qnum = 3; # MUST match constant sub arg
    my $title = "TBD";
    my $of = "{$date}-{$title}-query-{$qnum}.csv";
    say "Query $qnum is NYI";
}

#| 4. For a person (id), what years was the person an attendee or a
#| presenter
multi MAIN(4) {
    my $qnum = 4; # MUST match constant sub arg
    my $title = "TBD";
    my $of = "{$date}-{$title}-query-{$qnum}.csv";
    say "Query $qnum is NYI";
    my $pkey = prompt "Enter person key (see query 6): ";
}

#| 5. A list of all known valid emails for upload to a mail server
multi MAIN(5) {
    my $qnum = 5; # MUST match constant sub arg
    my $title = "TBD";
    my $of = "{$date}-{$title}-query-{$qnum}.csv";
    say "Query $qnum is NYI";
}

#| 6. List contacts with their ids
multi MAIN(6) {
    my $qnum = 6; # MUST match constant sub arg
    my $title = "TBD";
    my $of = "{$date}-{$title}-query-{$qnum}.csv";

    =begin comment
    my $p = Person.^all.grep(.last, .first, .id).map(last => ;
                                                     say $.p;


    my $p = Person.^all;
    my @rows = ($p.list ==>
             grep {.last} ==>
             grep {.first} ==>
             grep {.id}
              );
    my $p = Person.^all.list;
    spurt $of, $p.gist;
    =end comment

    #my $rs   = Person.^all;
    my $rs   = Person.^rs;
    my @cols = $rs.of.^attributes
                     .grep(Red::Attr::Column)
                     .map( -> $c { $c.name.substr(2) })
               ;

    my $str  = @cols.join("\t\t|");
    $str    ~= "\n" ~ ( '-' x 50 ) ~ "\n";

    for $rs -> $row {
        #$str ~= @cols.map( -> $n { $row."$n"() // ''})
        $str ~= @cols.map( -> $n { $row."$n"() // ''})
                     .join("\t\t|") ~ "\n";
    }

    =begin comment
    for $rs -> $row {
        for $row -> $c {
            if $c !~~ Nil { # .defined {
                $str ~= "|{$c}";
            }
            else {
                $str ~= "| ";
            }
        }

        $str ~= "|\n";
    }
    =end comment


    spurt $of, $str;
}
