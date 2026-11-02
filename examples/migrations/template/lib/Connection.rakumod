use Red;
use Red::DB;
unit module Connection;
#| Compatibility helper for older workshop steps. Red queries resolve the default automatically.
sub connection() is export { get-RED-DB() }
