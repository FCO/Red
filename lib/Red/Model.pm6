use Red::Filter;
unit role Red::Model;

has $!filter;
method where(Red::Filter $filter) {
    #FIXME
    ::?CLASS.new # FIXME: remove this line
}

method all { self.^rs }
