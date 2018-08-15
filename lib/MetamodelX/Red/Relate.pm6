use Red::Model;
use Red::ResultSeq;
unit role MetamodelX::Red::Relate;

#proto method relates( $, & ) {*}

multi method relates( Red::ResultSeq $obj, &filter ) {
    $obj.where( &filter )
}

multi method relates( Red::Model $obj, &filter ) {
    $obj.where( &filter ).head
}
