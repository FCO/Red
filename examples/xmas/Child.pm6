use Red;

unit model Child;

has UInt $!id              is id;
has Str  $.name            is column;
has Str  $.address         is column;

has      @.asked-by-year   is relationship( *.child-id, :model<ChildAskedOnYear> );

method asked(UInt $year = Date.today.year) {
    @!asked-by-year.grep: *.year == $year
}