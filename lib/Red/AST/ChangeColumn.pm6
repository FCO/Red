use Red::AST;
unit class Red::AST::ChangeColumn does Red::AST;

has Str  $.table is required;
has Str  $.name  is required;
has Str  $.type;
has Bool $.nullable;
has Bool $.pk;
has Bool $.unique;
has Str  $.ref-table;
has Str  $.ref-col;

method find-column-name {}
method args {}
method returns {}

# TODO: Fix
method optimize(@changes) {
    say @changes;
    my %lists = @changes.classify: { $_ ~~ ::?CLASS ?? "changes" !! "other" };
    say %lists;
    my %cols  = .?classify: { .say; .?name } with %lists<changes>;

    my @c = %cols.values.map({::?CLASS.new: |%(|.map({
        |("table"     , $_ with .table),
        |("name"      , $_ with .name),
        |("type"      , $_ with .type),
        |("nullable"  , $_ with .nullable),
        |("pk"        , $_ with .pk),
        |("unique"    , $_ with .unique),
        |("ref-table" , $_ with .ref-table),
        |("ref-col"   , $_ with .ref-col),
    }))});

    [
        |%lists<other>,
        |@c
    ]
}