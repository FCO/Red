use Red::Model;
use Red::Formatter::ResultSeq;
unit role Red::Formatter::ResultSeq::Vertical;
also does Red::Formatter::ResultSeq;

has UInt $.max-key-size;

method format-row(Red::Model $row) {
  my %values = $row.^column-values;
  do for $row.^columns>>.column>>.attr-name -> $name {
    "{ $name.fmt("% {$!max-key-size}s") }  | { %values{$name} }"
  }.join: "\n"
}
method row-header(Red::Model $row, UInt $line) {
  "******************************[ $line. row]******************************\n"
}

method TWEAK(|) {
  $!max-key-size = $.rs.of.^columns>>.column>>.attr-name>>.chars.max;
}
