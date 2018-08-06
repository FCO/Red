use Red::Filter;
unit role Red::Model;

has $!filter;
method where(Red::Filter $filter) {
    self.^rs.where: $filter
}
