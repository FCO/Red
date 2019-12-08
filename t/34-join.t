use Test;
#use Red;
#
#model Bla { ... }
#model Ble { ... }
#
#
#model Bla {
#    has UInt $.id     is serial;
#    has      @.ble    is relationship( *.bla-id, :model<Ble> );
#}
#
#model Ble {
#    has UInt $.id     is serial;
#    has UInt $.bla-id is referencing( *.id, :model<Bla> );
#    has Int  $.value  is column;
#}
#
#my $*RED-DB    = database "SQLite", |(:database($_) with %*ENV<RED_DATABASE>);
#my $*RED-DEBUG = True;
#Bla.^create-table; Ble.^create-table;
#
#Bla.^create: :ble[{ :1value }, { :2value }, { :3value }];
#
#is Bla.^join(Ble, *.id == *.bla-id).^all.Seq.map(*.value), <1 2 3>;
done-testing;
