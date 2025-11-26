use JSON::Fast;
use Red::Type;
use Red::DB;
unit class Json is Str does Red::Type;

method inflator {
  -> $data {
    # TODO: Find a better way of doing this
    do if get-RED-DB.?stringify-json  {
      $data ~~ Str ?? try { from-json $data } // $data !! $data
    } else {
      $data
    }
  }
}

method deflator {
  -> $data {
    # TODO: Find a better way of doing this
    do if get-RED-DB.?stringify-json  {
      try { to-json $data, :!pretty } // $data
    } else {
      $data
    }
  }
}

method red-type-accepts(Any:U --> Bool) { True }
