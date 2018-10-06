use v6.d.PREVIEW;
use Red::Model;
use Red::Attr::Column;
use Red::Column;
use Red::Utils;
use Red::ResultSeq;
use Red::DefaultResultSeq;
use Red::Attr::Query;
use Red::AST;

my package EXPORTHOW {
    package DECLARE {
        use MetamodelX::Red::Model;
        constant model = MetamodelX::Red::Model;
    }
}

sub EXPORT {
    use Red::Traits;
    use Red::Operators;
    use Red::Database;
    return %(
        Red::Traits::EXPORT::ALL::,
        Red::Operators::EXPORT::ALL::,
        :&database,
    );
}
