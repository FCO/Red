unit module Workshop;

class X::Workshop is Exception {
    has Str $.reason is required;
    method message { $!reason }
}

sub command(@arguments, IO::Path :$cwd = $*CWD, Str :$input,
            Bool :$check = False --> Hash) is export {
    my $process = Proc::Async.new(|@arguments.map(*.Str), :w($input.defined));
    my Str $out = '';
    my Str $err = '';
    $process.stdout.tap(-> $text { $out ~= $text });
    $process.stderr.tap(-> $text { $err ~= $text });
    my $done = $process.start(:$cwd);
    if $input.defined {
        await $process.print($input) if $input.chars;
        $process.close-stdin;
    }
    my $status = (await $done).exitcode;
    X::Workshop.new(:reason("Command failed ($status): {@arguments.join(' ')}\n$err$out")).throw
        if $check && $status;
    %( :$status, :$out, :$err )
}

sub make-directory(IO::Path $path) is export {
    make-directory($path.parent) unless $path.parent.d;
    $path.mkdir unless $path.d;
}

sub copy-tree(IO::Path $source, IO::Path $target) is export {
    X::Workshop.new(:reason("Symbolic links are unsupported: $source")).throw if $source.l;
    if $source.d {
        make-directory($target);
        for $source.dir.grep({ .basename ne '.precomp' }) -> $entry {
            copy-tree($entry, $target.add($entry.basename));
        }
    } else {
        make-directory($target.parent);
        $source.copy($target);
    }
}

sub remove-tree(IO::Path $path) is export {
    return unless $path.e;
    if $path.d && !$path.l {
        remove-tree($_) for $path.dir;
        $path.rmdir;
    } else { $path.unlink }
}

sub unique-directory(Str $prefix --> IO::Path) is export {
    my $path = $*TMPDIR.add("$prefix-{$*PID}-{now.Int}-{(10**12).rand.Int}");
    $path.mkdir;
    $path
}

sub steps(IO::Path $document --> Array) is export {
    my @blocks;
    my @lines;
    my $marked = False;
    my $inside = False;
    my $context = 'host';
    for $document.lines -> $line {
        if $line eq any('<!-- workshop:run -->', '<!-- workshop:run host -->', '<!-- workshop:run dev -->') {
            $context = $line eq '<!-- workshop:run dev -->' ?? 'dev' !! 'host';
            $marked = True; next;
        }
        if $marked && $line eq '```bash' { $inside = True; $marked = False; next }
        if $inside && $line eq '```' {
            @blocks.push(%(source => @lines.join("\n"), :$context));
            @lines = (); $inside = False;
        } elsif $inside { @lines.push($line) }
    }
    X::Workshop.new(:reason('Unclosed executable chapter')).throw if $inside || $marked;
    @blocks.Array
}

sub chapters(IO::Path $document --> Array) is export {
    steps($document).map(*.<source>).Array
}
