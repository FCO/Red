use JSON::Fast;
unit class Json is Str;

method inflator { -> $data { try { from-json $data } // $data } }
method deflator { -> $data { try { to-json $data   } // $data } }