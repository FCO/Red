use Red;
use UUID;
use JSON::Fast;
use X::Red::Migration;
use Red::Migration::Storage;
=head2 Red::Migration::Environment

unit module Red::Migration::Environment;

#| Open the disposable connection described by RED_MIGRATION_TEST. Return Nil when no test context
#| is active so application code can select its normal configuration.
sub test-database() is export {
    return Nil unless %*ENV<RED_MIGRATION_TEST>;
    my %context = from-json %*ENV<RED_MIGRATION_TEST>.IO.slurp;
    database %context<driver>, |%context<parameters>
}

#| Provision an isolated SQLite file or uniquely named native database and call the supplied body
#| with its connection, context file and parameters. Clean up on success or failure unless keep is
#| requested; native servers need database creation and removal privileges.
sub temporary-database(Str $driver, %server, &body, Bool :$keep = False) is export {
    provision-database($driver, %server, &body, %*ENV.Hash, :$keep)
}

#| Isolate migration context changes while preserving the caller's environment, including native
#| database credentials and library paths. Capture it before declaring the dynamic environment.
sub provision-database(Str $driver, %server, &body, %environment, Bool :$keep) {
    my %*ENV = %environment;
    %*ENV<RED_MIGRATION_TEST>:delete;
    my $name = 'red_migration_test_' ~ UUID.new.Str.subst('-', '', :g).lc;
    my $folder = $*TMPDIR.add($name);
    $folder.mkdir;
    my $admin;
    my $created = False;
    my %parameters = %server;
    my $result;
    my Exception $body-error;
    CATCH { default { $body-error = $_; .rethrow } }
    LEAVE {
        if !$keep && $folder.defined && $folder.d {
            my Exception $cleanup-error;
            if $created {
                try {
                    if $driver eq 'Pg' {
                        $admin.execute('DROP DATABASE ' ~ $admin.table-name-wrapper($name) ~ ' WITH (FORCE)');
                    } elsif $driver eq 'MySQL' {
                        $admin.execute('DROP DATABASE ' ~ $admin.table-name-wrapper($name));
                    }
                    CATCH { default { $cleanup-error = $_ } }
                }
            }
            if $cleanup-error.defined {
                X::Red::Migration.new(:cause($cleanup-error),
                    :reason("Failed to remove temporary $driver database $name; metadata retained at $folder. "
                        ~ ($body-error.defined ?? "Original failure: {$body-error.message}" !! ''))).throw;
            }
            remove-tree($folder);
        }
    }
    if $driver eq 'SQLite' {
        %parameters = database => $folder.add('test.sqlite').Str;
    } elsif $driver eq any(<Pg MySQL>) {
        X::Red::Migration.new(:reason("Configure a test server for $driver")).throw unless %server;
        my %admin = %server;
        if $driver eq 'Pg' { %admin<dbname> //= 'postgres' }
        else { %admin<database> //= 'mysql' }
        $admin = database $driver, |%admin;
        $admin.execute('CREATE DATABASE ' ~ $admin.table-name-wrapper($name));
        $created = True;
        %parameters{$driver eq 'Pg' ?? 'dbname' !! 'database'} = $name;
    } else {
        X::Red::Migration.new(:reason("Unsupported temporary driver: $driver")).throw;
    }
    my $context = $folder.add('connection.json');
    $context.spurt(to-json(%( :$driver, :%parameters )));
    $context.chmod(0o600);
    note "Temporary migration database retained: $context" if $keep;
    $result = body(database($driver, |%parameters), $context, %parameters);
    $result
}
