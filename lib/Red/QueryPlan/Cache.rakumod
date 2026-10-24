#| A bounded, synchronized cache. Clones may share it; keys describe the full plan.
unit class Red::QueryPlan::Cache;

has UInt $.capacity = 128;
has Lock $!lock .= new;
has %!entries;
has Int %!recent;
has Int $!clock = 0;
has Str $!recent-key;

method !touch(Str:D $key) {
    return if $!recent-key.DEFINITE && $!recent-key eq $key;
    %!recent{$key} = ++$!clock;
    $!recent-key = $key;
}

method fetch(Str:D $key, &build --> Pair:D) {
    my $cached = $!lock.protect: {
        if %!entries{$key}:exists {
            self!touch($key);
            'hit' => %!entries{$key}
        } else {
            Nil
        }
    };
    return $cached if $cached.DEFINITE;
    # Builders may call user diagnostics; never run those under the cache lock.
    my $value = build();
    $!lock.protect: {
        my $hit = %!entries{$key}:exists;
        %!entries{$key} = $value unless $hit;
        self!touch($key);
        my $entry = ($hit ?? 'hit' !! 'miss') => %!entries{$key};
        # Hits update one timestamp; scan only when inserting beyond capacity.
        while %!entries.elems > $!capacity {
            my $oldest = %!recent.keys.min({ %!recent{$_} });
            %!recent{$oldest}:delete;
            %!entries{$oldest}:delete;
            $!recent-key = Str if $!recent-key eq $oldest;
        }
        $entry
    }
}
