use Red::Utils;
unit role Red::Formatter;

method table-formatter($data)  {
    do if self.?experimental-formatter {
        &*RED-TABLE-FORMATTER  andthen .($data) orelse camel-to-snake-case $data
    } else {
        camel-to-snake-case $data
    }
}
method column-formatter($data) {
    do if self.?experimental-formatter {
        &*RED-COLUMN-FORMATTER andthen .($data) orelse kebab-to-snake-case $data
    } else {
        kebab-to-snake-case $data
    }
}
