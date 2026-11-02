use nqp;
use Red::Migration::SQL;
use X::Red::Migration;
=head2 Red::Migration::Scripts

unit module Red::Migration::Scripts;

#| Read one SQL direction in numeric file order, accepting either legacy up.sql/down.sql or numbered
#| directory files. Return statements, file identities and checksums; reject mixed formats and
#| duplicate numbers.
sub read-direction(IO() $root, Str $direction, Str $dialect --> Hash) is export {
    my $legacy = $root.add("$direction.sql");
    my $directory = $root.add($direction);
    X::Red::Migration.new(:reason("Mixed migration formats: $root/$direction")).throw
        if $legacy.e && $directory.e;
    my @files;
    if $legacy.f { @files = $legacy }
    elsif $directory.d {
        my %numbers;
        for $directory.dir.grep({ !.basename.starts-with('.') }) -> $file {
            my $match = $file.basename.match(/^ (\d ** 3..*) '-' <[A..Za..z0..9_-]>+ '.sql' $/);
            X::Red::Migration.new(:reason("Invalid migration filename: $file")).throw
                unless $file.f && $match;
            my $number = +$match[0];
            X::Red::Migration.new(:reason("Duplicate migration file number: $file")).throw
                if %numbers{$number}:exists;
            %numbers{$number} = $file;
        }
        @files = %numbers.keys.sort(*.Int).map({ %numbers{$_} });
    } else {
        X::Red::Migration.new(:reason("Missing migration direction: $root/$direction")).throw;
    }
    my @instructions;
    my @fingerprints;
    for @files -> $file {
        my $source = $file.slurp;
        my $name = $legacy.f ?? $file.basename !! "$direction/{$file.basename}";
        my $hash = nqp::sha1($source);
        @fingerprints.push: %(file => $name, checksum => $hash);
        for statements($source, :$dialect).kv -> $index, $sql {
            @instructions.push: %(file => $name, statement => $index + 1, :$sql, checksum => $hash);
        }
    }
    my $checksum = $legacy.f
        ?? nqp::sha1($legacy.slurp)
        !! nqp::sha1(@fingerprints.map({ .<file>.raku ~ ':' ~ .<checksum> }).join("\n"));
    %( :$checksum, files => @fingerprints.Array, instructions => @instructions.Array,
        sql => @instructions.map(*.<sql>).Array )
}

#| Write generated SQL to direction/001-schema.sql, replacing a legacy single-file direction when
#| present.
sub write-direction(IO() $root, Str $direction, Str $source) is export {
    my $directory = $root.add($direction);
    $directory.mkdir unless $directory.d;
    $directory.add('001-schema.sql').spurt($source);
}
