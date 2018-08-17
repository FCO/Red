use Red::Model;
use Red::AST;

unit class Red::Query;

has Mu:U        $.base-table is required;
has Red::AST $.filter = $!base-table.all;

method TWEAK(|) {
    my \Alias = $!base-table.^alias: "me";
    say Alias;
    $!filter .= substitute: :{ $!base-table => Alias }
    $!base-table = Alias
}
