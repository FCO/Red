use JSON::Fast;
unit class Json is Str;

method inflator { &from-json }
method deflator { &to-json }