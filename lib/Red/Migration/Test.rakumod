use Test;
use Red::Migration::Configuration;
use Red::Migration::Manager;
=head2 Red::Migration::Test

unit module Red::Migration::Test;

#| Add a Test subtest that validates the configured history on disposable databases. Forward options
#| to Manager.test and report execution or schema failures as failed assertions.
sub migration-ok(IO() $configuration = 'red.rakuconf', |options) is export {
    subtest 'Migration history builds and validates on empty databases', {
        lives-ok {
            Red::Migration::Manager.new(
                :config(Red::Migration::Configuration.load($configuration))).test(|options)
        }, 'all configured migration drivers pass';
    }
}
