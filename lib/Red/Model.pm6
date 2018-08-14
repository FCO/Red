use Red::Filter;
unit role Red::Model;

has $!filter;
multi method where(Red::Filter $filter) {
    self.^rs.where: $filter
}

multi method where(&filter) {
    self.^rs.where: filter ::?CLASS
}

method relates( &filter ) {
    self.where( &filter ).head
}

method all { self.^rs }

method gist { self.perl }
