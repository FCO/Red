use Test;
use Red;

plan 34;

my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my @conf                = (%*ENV<RED_DATABASE> // "SQLite").split(" ");
my $driver              = @conf.shift;
my $*RED-DB             = database $driver, |%( @conf.map: { do given .split: "=" { .[0] => .[1] } } );

my %call-count;

role TestPhasersRole {
    method before-create-role-public() is before-create {
        %call-count{ &?ROUTINE.name }++;
    }
    method after-create-role-public() is after-create {
        %call-count{ &?ROUTINE.name }++;
    }
    method before-update-role-public() is before-update {
        %call-count{ &?ROUTINE.name }++;
    }
    method after-update-role-public() is after-update {
        %call-count{ &?ROUTINE.name }++;
    }
    method before-delete-role-public() is before-delete {
        %call-count{ &?ROUTINE.name }++;
    }
    method after-delete-role-public() is after-delete {
        %call-count{ &?ROUTINE.name }++;
    }
    method !before-create-role-private() is before-create {
        %call-count{ &?ROUTINE.name }++;
    }
    method !after-create-role-private() is after-create {
        %call-count{ &?ROUTINE.name }++;
    }
    method !before-update-role-private() is before-update {
        %call-count{ &?ROUTINE.name }++;
    }
    method !after-update-role-private() is after-update {
        %call-count{ &?ROUTINE.name }++;
    }
    method !before-delete-role-private() is before-delete {
        %call-count{ &?ROUTINE.name }++;
    }
    method !after-delete-role-private() is after-delete {
        %call-count{ &?ROUTINE.name }++;
    }
}

model TestPhasers does TestPhasersRole {
    has Int $.id is serial;
    has Str $.name is column is rw;
    has Int $.int  is column is rw = 0;

    method before-create-model-public() is before-create {
        %call-count{ &?ROUTINE.name }++;
    }
    method after-create-model-public() is after-create {
        %call-count{ &?ROUTINE.name }++;
    }
    method before-update-model-public($_) is before-update {
        %call-count{ &?ROUTINE.name }++;
        .int++
    }
    method after-update-model-public() is after-update {
        %call-count{ &?ROUTINE.name }++;
    }
    method before-delete-model-public() is before-delete {
        %call-count{ &?ROUTINE.name }++;
    }
    method after-delete-model-public() is after-delete {
        %call-count{ &?ROUTINE.name }++;
    }
    method !before-create-model-private() is before-create {
        %call-count{ &?ROUTINE.name }++;
    }
    method !after-create-model-private() is after-create {
        %call-count{ &?ROUTINE.name }++;
    }
    method !before-update-model-private() is before-update {
        %call-count{ &?ROUTINE.name }++;
    }
    method !after-update-model-private() is after-update {
        %call-count{ &?ROUTINE.name }++;
    }
    method !before-delete-model-private() is before-delete {
        %call-count{ &?ROUTINE.name }++;
    }
    method !after-delete-model-private() is after-delete {
        %call-count{ &?ROUTINE.name }++;
    }
}

sub call-count-ok (Str:D $phaser, Int:D $expected = 1, Str :$msg?) {
    for <public private> -> $visibility {
        for <before after> -> $stage {
            for <role model> -> $where {
                my $method = "{ $stage }-{ $phaser }-{ $where }-{ $visibility }";
                is %call-count{$method}, $expected, 
                    "$visibility $stage $phaser phaser on $where was called exactly $expected times" 
                    ~ ($msg ?? " $msg" !! "") ;
            }
        }
    }
}

TestPhasers.^create-table;

my $test-row = TestPhasers.^create(name => "test");
call-count-ok 'create';

$test-row.name = "something else";
$test-row.^save;
call-count-ok 'update';

$test-row.^delete;
call-count-ok 'delete';

$test-row = TestPhasers.new(name => "test two");
$test-row.^save(:insert);
call-count-ok 'create', 2, msg => "when using ^save(:insert)";

TestPhasers.^all.map(*.name ~= "!").save;
is TestPhasers.^all.map(*.int), (1);
is TestPhasers.^all.map(*.name), ("test two!");

done-testing;

# vim: ft=perl6
