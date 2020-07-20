use Red::Utils;
unit role Red::Formater;

method table-formater($data)  {
    do if self.?experimental-formater {
        &*RED-TABLE-FORMATER  andthen .($data) orelse camel-to-snake-case $data
    } else {
        camel-to-snake-case $data
    }
}
method column-formater($data) {
    do if self.?experimental-formater {
        &*RED-COLUMN-FORMATER andthen .($data) orelse kebab-to-snake-case $data
    } else {
        kebab-to-snake-case $data
    }
}