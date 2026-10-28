use nqp;
use X::Red::Exceptions;

#| Resolve static Unicode properties to scalar-value ranges at compilation time.
#| SQL receives data, never executable Raku or an interpolated property expression.
unit module Red::Regex::Unicode;

my %cache;
my Lock $lock .= new;

sub property-ranges(Str:D $property, Str :$value --> List:D) is export {
    my $key = $property ~ '=' ~ ($value // '<binary>');
    $lock.protect: {
        return %cache{$key} if %cache{$key}:exists;
        my int $code = nqp::unipropcode($property);
        sub unsupported {
            X::Red::Compiler::Unsupported.new(:fatal,
                :reason("Unsupported static Unicode property: $key")).throw
        }
        unsupported unless $code;
        my $wanted-name = $value // ($code == nqp::unipropcode('General_Category')
            ?? $property !! 'True');
        # Aggregate categories such as L are binary aliases rather than a single
        # General_Category value. Resolve those aliases before enumerating.
        if $code == nqp::unipropcode('General_Category')
            && $wanted-name eq any(<L M N P S Z C LC Letter Mark Number Punctuation
                Symbol Separator Other Cased_Letter>) {
            $code = nqp::unipropcode($wanted-name);
        }
        my int $wanted = nqp::unipvalcode($code, $wanted-name);
        $wanted ||= nqp::unipvalcode($code, $wanted-name.subst(/ <[\x20_\x2D]> /, '', :g));
        $wanted = nqp::unipvalcode($code, $property) if !$value.defined && !$wanted;
        unless $wanted {
            my &normalize = -> Str $name { $name.lc.subst(/ <[\x20_\x2D]> /, '', :g) };
            my $name = normalize($wanted-name);
            my $binary = $code != nqp::unipropcode('General_Category')
                && $code != nqp::unipropcode('Script')
                && (nqp::unipvalcode($code, 'True')
                    || nqp::unipvalcode($code, 'Yes') || nqp::unipvalcode($code, $property));
            my $valid = so $binary && $name eq any(<false no n>);
            $valid ||= $code == nqp::unipropcode('General_Category')
                && $name eq any(<cn unassigned>);
            $valid ||= $code == nqp::unipropcode('Script')
                && $name eq any(<unknown zzzz>);
            unless $valid {
                # A zero result also means an unknown value. Accept an enum's
                # actual zero spelling, not an arbitrary unknown name.
                loop (my int $point = 0; $point < 0x110000; $point++) {
                    if nqp::getuniprop_int($point, $code) == 0 {
                        $valid = $name eq normalize(nqp::getuniprop_str($point, $code));
                        last;
                    }
                }
            }
            unsupported unless $valid;
        }
        my @ranges;
        my int $start = -1;
        loop (my int $point = 1; $point <= 0x110000; $point++) {
            my int $matches = $point < 0x110000
                && !($point >= 0xD800 && $point <= 0xDFFF)
                && nqp::getuniprop_int($point, $code) == $wanted;
            if $matches {
                $start = $point if $start == -1;
            } elsif $start != -1 {
                @ranges.push: (nqp::box_i($start, Int), nqp::box_i($point - 1, Int)).List;
                $start = -1;
            }
        }
        %cache{$key} = @ranges.List
    }
}
