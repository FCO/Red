use JSON::Fast;
use Red::Type;
unit class Json is Str does Red::Type;

method inflator { -> $data { try { from-json $data } // $data } }
method deflator { -> $data { try { to-json $data   } // $data } }

method red-type-accepts(Any:U --> Bool) { True }
