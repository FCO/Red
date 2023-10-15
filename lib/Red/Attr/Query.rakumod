unit role Red::Attr::Query;

method wrapper($obj, $query) {
    #TODO
    now # FIXME: run the query
}

method wrap-data($filter) {
    my $name = self.name.substr: 2;
    my \attr = self;
    with self.package.^lookup: $name {
        .wrap: method { attr.wrapper: attr, $filter }
    } elsif self.has_accessor {
        self.package.^add_method: $name, method (|) { attr.wrapper: self, $filter }
    }
}

