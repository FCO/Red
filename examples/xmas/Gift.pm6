use Red:api<2>;

unit model Gift;

has UInt $!id            is serial;
has Str  $.name          is column{ :unique };

has      @.asked-by-year is relationship( *.gift-id, :model<ChildAskedOnYear> );

method child-asked-on-year(UInt $year = Date.today.year) {
    self.asked-by-year.grep: *.year == $year
}

method asked-by(UInt $year) {
    self.child-asked-on-year(|($_ with $year)).map: *.child
}