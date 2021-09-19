use Red::AST;
use Red::Model;
use Red::AST::Infixes;
use Red::AST::Value;
use Red::AST::Function;

=head2 Red::ResultAssociative

#| Lazy Associative class from Red queries (.classify)
unit role Red::ResultAssociative[$of, $key-of where { $_ ~~ Red::AST || $_ ~~ List && .all ~~ Red::AST }] does Associative;

has $!key-of = $key-of;
has $.rs is required;
has @.asked-keys;

#| type of the value
method of     { $of }

#| type of the key
method key-of { $!key-of.returns }

method !get-filter {
    my @keys = @!asked-keys.clone;
    do if @keys == 0 {
        True
    } elsif @keys == 1 {
        Red::AST::Eq.new: $!key-of<>.head, ast-value(@keys.head), :bind-right
    } else {
        $!key-of<>.head(@keys).reduce: -> $agg is copy, $c {
            if $agg !~~ Red::AST::Eq {
                $agg = Red::AST::Eq.new: $agg, ast-value(@keys.shift), :bind-right
            }
            Red::AST::AND.new: $agg, Red::AST::Eq.new: $c, ast-value(@keys.shift), :bind-right;
        }
    }
}

#| return a list of keys
#| run a SQL query to get it
method keys {
    my $rs = $!rs.map({ |$key-of.tail(*-@!asked-keys).head }).grep: { self!get-filter }
    $rs.group = $key-of<>.tail(*-@!asked-keys).head;
    $rs
}

method values {
    my @keys = $.keys.Seq;
    @keys.map: { self.AT-KEY: $_ }
}

#| Run query to get the number of elements
method elems {
    my $rs = $!rs.map: { 1 }
    $rs.group = $key-of<>;
    $rs.elems
}

#| return a ResultSeq for the given key
method AT-KEY(Str() $key) {
    my @keys = |@!asked-keys, $key.Str;
    my $num-of-keys = +@!asked-keys;
    do if @keys == $!key-of.elems {
        my $cond = $!key-of<>.reduce: -> $agg is copy, $c {
            if $agg !~~ Red::AST::Eq {
                $agg = Red::AST::Eq.new: $agg, ast-value(@keys.shift), :bind-right
            }
            Red::AST::AND.new: $agg, Red::AST::Eq.new: $c, ast-value(@keys.shift), :bind-right;
        }
        $!rs.grep: { $cond }
    } else {
        self.clone: :asked-keys(@keys)
    }
}

method iterator {
    gather for $.keys.Seq.grep: { .DEFINITE } { take $_ => self.AT-KEY: $_ }.iterator
}

method gist {
    "\{{self.map({ "{.key} => {.value.gist}" }).join: ", "}\}"
}

#| Run query to create a Bag
method Bag {
    my $rs = $!rs.map({ ($key-of, Red::AST::Function.new(:func<COUNT>, :args[ast-value("*"),], :returns(Int))) });
    $rs.group = $!key-of;
    $rs.Seq.map({ .[0] => .[1] }).Bag
}

#| Run query to create a Set
method Set {
    my $rs = $!rs.map({ Red::AST::Function.new(:func<DISTINCT>, :args[$key-of], :returns(Int)) });
    $rs.Seq.Set
}
