use Red::Filter;
unit role Red::ResultSet;

has Red::Filter $.filter;

multi method where(::?CLASS:U: Red::Filter:D $filter) { self.new: :$filter }
multi method where(::?CLASS:D: Red::Filter:D $filter) { self.clone: :filter($!filter.merge: $filter) }
