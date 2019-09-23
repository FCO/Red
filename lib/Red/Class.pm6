unit class Red::Class;

method instance(::?CLASS:U: --> ::?CLASS:D) { $ //= self.bless }
method new {!!!}

has Supplier $!supplier .= new;
has Supply   $.events    = $!supplier.Supply;

method register-supply(Supply $_) {
    .tap: { $!supplier.emit: $_ }
}