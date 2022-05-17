use Red::Model;
unit role Red::Formatter::ResultSeq;

has $.rs;

method format {
  do for $!rs.Seq -> $row {
    self.row-header($row, ++$),
    self.format-row($row),
    self.row-footer($row, ++$),
    "\n"
  }.flat.join
}

method format-row(Red::Model $row)             { Empty }
method row-header(Red::Model $row, UInt $line) { Empty }
method row-footer(Red::Model $row, UInt $line) { Empty }
