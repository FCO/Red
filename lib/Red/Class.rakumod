#| Base class for Red methods
unit class Red::Class;

#| Return a instance of Red::Class
method instance(::?CLASS:U: --> ::?CLASS:D) { $ //= self.bless }
method new {!!!}

has Supplier $!supplier .= new;
#| Supply that emit Red events
has Supply   $.events    = $!supplier.Supply;

#| Register a new supply to send events
method register-supply(Supply $_) {
    .tap: { $!supplier.emit: $_ }
}
