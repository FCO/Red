use Red::Model;
use Red::ResultSeq;
unit role MetamodelX::Red::Relate;

#proto method relates( $, & ) {*}

multi method relates( Red::ResultSeq $obj, &filter ) {
    $obj.grep( &filter )
}

multi method relates( Red::Model $obj, &filter ) {
    $obj.grep( &filter ).head
}
