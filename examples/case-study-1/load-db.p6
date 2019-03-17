#!/usr/bin/env perl6

use Red;

use lib $*PROGRAM.parent.add('lib');
use OurFuncs;
# the Red models
use Present;
use Attend;
use Email;
use Person;

my $dbf-local = 'data/ctech.sqlite';
my $dbf = $*PROGRAM.parent.add($dbf-local).absolute;

my $f   = './data/attendees.csv';

# use the following in-memory version and Red debug until
# getting desired results
my $*RED-DEBUG = 1;
=begin comment
my $*RED-DB = database "SQLite";
=end comment
my $*RED-DB = database "SQLite", :database($dbf);

if !@*ARGS {
    say qq:to/HERE/;
    Usage: $*PROGRAM go

    Reads data from CSV file '$f' and
    loads them into an SQLite database
    (file '$dbf-local').
    HERE
    exit;
}

my $dbf-updated = 0;

for Person, Attend, Email, Present -> $model {
    $model.^create-table(:if-not-exists);
}

my %keys = SetHash.new ; # check for dups
for $f.IO.lines -> $line {
    my @w = split $COMMA, $line;
    my $last  = tclc @w.shift;
    my $first = tclc @w.shift;
    # rest of data may vary
    my %a = SetHash.new;
    my %e = SetHash.new;
    my %p = SetHash.new;

    # TODO use a grammar to extract data from the input line
    for @w -> $w is copy {
        $w .= trim;
        if $w ~~ /(\d**4) (:i p)?/ {
            my $year = ~$0;
            if  $1 {
                %p{$year}++;
            }
            else {
                %a{$year}++;
            }
        }
        elsif $w ~~ /'@'/ {
            $w .= lc;
            %e{$w}++;
        }
        else {
            note "FATAL: Unexpected data word '$w'";
            die  "line: '$line'";
        }
    }

    # put in db
    # get a key for Person
    my $key = create-csv-key :$last, :$first, :e-mail(%e);
    # unique?
    if %keys{$key}:exists {
        die "FATAL: key '$key' is NOT unique.";
    }
    else {
        %keys{$key}++;
    }

    # we have the data, insert into the four tables if not there
    # already
    my $x = Person.^all.grep({.key eq $key});
    if !$x {
        ++$dbf-updated;
        my $p = Person.^create(:key($key), :last($last), :first($first));
        # check each child table's entry
        for %a.keys -> $year {
            $p.attends.create: :$year unless $p.attends.grep: *.year == $year;
        }
        for %e.keys -> $email {
            $p.emails.create: :$email unless $p.emails.grep: *.email eq $email;
        }
        for %p.keys -> $year {
            $p.presents.create: :$year unless $p.presents.grep: *.year == $year;
        }
    }
}

say "Normal end.";
if $dbf.IO.f {
    if $dbf-updated {
        say "Updated data are in database file '$dbf-local'.";
    }
    else {
        say "No data were updated in database file '$dbf-local'.";
    }
}
