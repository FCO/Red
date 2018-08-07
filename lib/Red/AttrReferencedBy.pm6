use Red::AttrQuery;
unit role Red::AttrReferencedBy does Red::AttrQuery;

method wrapper($obj, &filter) {
    my \type = do if self.type.?of === Nil {
        self.type
    } else {
        self.type.of
    }
    type.^rs.where: filter($obj, type)
}

