use v6.d.PREVIEW;
use Red::Model;
use Red::Attr::Column;
use Red::Column;
use Red::Utils;
use Red::ResultSeq;
use Red::DefaultResultSeq;
use Red::Attr::ReferencedBy;
use Red::Attr::Query;
use Red::AST;

my package EXPORTHOW {
    package DECLARE {
        use MetamodelX::Red::Model;
        constant model = MetamodelX::Red::Model;
    }
}

my package EXPORT::DEFAULT {
    use Red::Traits;
    use Red::Operators;
    use Red::Database;
    for Red::Traits::EXPORT::ALL::.keys -> $key {
        OUR::{$key} := Red::Traits::EXPORT::ALL::{ $key }
    }
    for Red::Operators::EXPORT::ALL::.keys -> $key {
        OUR::{$key} := Red::Operators::EXPORT::ALL::{ $key }
    }
    OUR::{"&database"} := &database;
}
