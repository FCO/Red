use Red;

model Person is rw {
    has Int  $.id            is serial;
    has Str  $.name          is column;
    has      @.posts         is relationship({ .author-id }, :model<Post>);
    method active-posts { @!posts.grep: not *.deleted }
}


