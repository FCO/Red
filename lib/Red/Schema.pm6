use Red::Do;
use Red::DB;
use Red::Driver::Pg;
unit class Red::Schema;

sub schema(+@models) is export {
    ::?CLASS.new: @models
}

has %.models;

method new(@models) {
    my %models = @models.map: {
        do if $_ ~~ Str {
            require ::($_);
            $_ => ::($_)
        } else {
            .^name => $_
        }
    }
    self.bless: :%models
}

method FALLBACK(Str $name) {
    do if %!models{ $name }:exists {
        %!models{ $name }
    } else {
        fail "Model '$name' not found on schema"
    }
}

# TODO: For tests only, please make it right
method drop {
    for %!models.values {
        say "DROP TABLE IF EXISTS { .^table } CASCADE";
        get-RED-DB.execute: "DROP TABLE IF EXISTS { .^table } { "CASCADE" if get-RED-DB.^isa: Red::Driver::Pg }";
    }
    self
}

method create(:$where) {
    red-do (:$where with $where), :transaction, {
        %( |.create-schema(%!models) )
    }
    self
}