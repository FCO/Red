unit class CITestSetManager;
use DB;

method add-test-set() {
    my @asdf = DB::CITestSet.^all.grep(*.status ⊂ <NEW SOURCE_ARCHIVE_CREATED WAITING_FOR_TEST_RESULTS>);
}

method add-test-set2() {
    my @asdf = DB::CITestSet.^all.map(*.status ⊂ <NEW SOURCE_ARCHIVE_CREATED WAITING_FOR_TEST_RESULTS>);
}

method add-test-set3() {
    my @asdf = DB::CITestSet.^all.first(*.status ⊂ <NEW SOURCE_ARCHIVE_CREATED WAITING_FOR_TEST_RESULTS>);
}
