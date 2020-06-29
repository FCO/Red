use Red::Do;
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

method FALLBACK(Str $name) { %!models{ $name } }

method create(:$where) {
    red-do (:$where with $where), :transaction, {
        %( |.create-schema(%!models) )
    }
    self
}