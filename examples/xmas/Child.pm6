use Red:api<2>;

unit model Child;

has UInt $!id              is serial;
has Str  $.name            is column;
has Str  $.country         is column;

has      @.asked-by-year   is relationship( *.child-id, :model<ChildAskedOnYear> );

method asked(UInt $year = Date.today.year) {
    self.asked-by-year.grep: *.year == $year
}