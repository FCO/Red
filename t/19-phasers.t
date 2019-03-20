use Test;

use Red;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DB             = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);


my $before-create   = 0;
my $after-create    = 0;
my $before-update   = 0;
my $after-update    = 0;
my $before-delete   = 0;
my $after-delete    = 0;

role TestPhasersRole {
    method before-create-role() is before-create {
        $before-create++
    }
    method after-create-role() is after-create {
        $after-create++
    }
    method before-update-role() is before-update {
        $before-update++
    }
    method after-update-role() is after-update {
        $after-update++
    }
    method before-delete-role() is before-delete {
        $before-delete++
    }
    method after-delete-role() is after-delete {
        $after-delete++
    }
}

model TestPhasers does TestPhasersRole {
    has Int $.id is serial;
    has Str $.name is column is rw;

    method before-create-model() is before-create {
        $before-create++
    }
    method after-create-model() is after-create {
        $after-create++
    }
    method before-update-model() is before-update {
        $before-update++
    }
    method after-update-model() is after-update {
        $after-update++
    }
    method before-delete-model() is before-delete {
        $before-delete++
    }
    method after-delete-model() is after-delete {
        $after-delete++
    }
}

TestPhasers.^create-table;

my $test-row = TestPhasers.^create(name => "test");
is $before-create, 2, "before-create got called the right number of times";
is $after-create, 2, "after-create got called the right number of times";

$test-row.name = "something else";
$test-row.^save;
is $before-update, 2, "before-update got called the right number of times";
is $after-update, 2, "after-update got called the right number of times";

$test-row.^delete;
is $before-delete, 2, "before-delete got called the right number of times";
is $after-delete, 2, "after-delete got called the right number of times";

$before-create  = 0;
$after-create   = 0;

$test-row = TestPhasers.new(name => "test two");
$test-row.^save(:insert);
is $before-create, 2, "before-create got called the right number of times when using ^save(:insert)";
is $after-create, 2, "after-create got called the right number of times when using ^save(:insert)";

done-testing;

# vim: ft=perl6
