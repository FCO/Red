use Red:api<2>;

unit model ChildAskedOnYear;

has UInt $!id       is serial;
has UInt $.year     is column = Date.today.year;
has UInt $!child-id is referencing(*.id, :model<Child>);
has UInt $!gift-id  is referencing(*.id, :model<Gift>);

has      $.child    is relationship( *.child-id, :model<Child> );
has      $.gift     is relationship( *.gift-id,  :model<Gift>  );