use Test;
use Red <shortname>;
use lib "t/lib";
use Experimental1;
use Experimental2;
use Experimental3;

is (model Bla::Ble::Bli {}).^experimental-name, "Bli"
