use Red::Attr::Query;
unit role Red::Attr::ReferencedBy does Red::Attr::Query;

method wrapper($obj, &filter) {
    my \type = do if self.type.?of === Nil {
        self.type
    } else {
        self.type.of
    }
    type.^rs.where: filter($obj, type)
}

