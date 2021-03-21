use v6;
use Red;

model Person is rw {
    has Int  $.id            is serial;
    has Str  $.name          is unique;
    has      @.posts         is relationship({ .author-id }, model => 'Post');
}
