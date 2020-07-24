use Red;
use Test;

plan :skip-all("Different driver setted ($_)") with %*ENV<RED_DATABASE>;

model Bla{ has Str $.id is id }
model Ble{ has Str $.other-name is id }

is Bla.^new-with-id("blablabla").id, "blablabla";
is Ble.^new-with-id("blablabla").other-name, "blablabla";

done-testing;
