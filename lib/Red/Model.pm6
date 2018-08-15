use Red::Filter;
unit role Red::Model;

has $!filter;
multi method where(Red::Filter $filter) {
    self.^rs.where: $filter
}

multi method where(&filter) {
    self.^rs.where: filter ::?CLASS
}

method all { self.^rs }

method gist { self.perl }
