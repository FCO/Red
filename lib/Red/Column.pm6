use Red::Utils;
use Red::Model;
use Red::AST;
use Red::AST::IsDefined;
use Red::AST::Unary;
unit class Red::Column does Red::AST;

has Attribute   $.attr is required;
has Str         $.attr-name        = $!attr.name.substr: 2;
has Bool        $.id               = False;
has Bool        $.auto-increment   = False;
has             &.references;
has             $!ref;
has Bool        $.nullable         = $!attr.package.^default-nullable;
has Str         $.name             = kebab-to-snake-case self.attr.name.substr: 2;
has Mu          $.class is required;
has Str         $.name-alias       = $!name;
has Str         $.type;
has             &.inflate          = *.self;
has             &.deflate          = *.self;
has             $.computation;
has Str         $.references-model;
has Str         $.references-key;

class ReferencesProxy does Callable {
    has Str     $.references-model is required;
    has Str     $.references-key   is required;
    has         $.model;
    has Bool    $!tried-model  = False;

    method model( --> Mu:U ) {
        if !$!tried-model {
            my $model = ::($!references-model);
            if !$model && $model ~~ Failure {
                $model = (require ::($!references-model))
            }
            $!model = $model;
            $!tried-model = True;
        }
        $!model;
    }

    method CALL-ME {
        self.model."{ $!references-key }"()
    }
}

method references(--> Callable) is rw {
    &!references //= do {
        if $!references-model && $!references-key {
            ReferencesProxy.new(:$!references-model, :$!references-key);
        }
        else {
            Callable
        }
    }
}

method ref {
    $!ref //= .() with self.references
}

method returns { $!class }

method transpose(&func) { func self }

method gist { "{$!class.^as}.{$!name-alias}" }

method cast(Str $type) {
    Red::AST::Cast.new: self, $type
}

method find-column-name {
    $!attr-name
}

method alias(Str $name) {
    self.clone: name-alias => $name
}

method as(Str $name, :$nullable = True) {
    self.clone: attr-name => $name, :$name, id => False, :$nullable, attr => Attribute, class => Mu
}

method TWEAK(:$unique) {
    if $unique {
        $!attr.package.^add-unique-constraint: { self }
    }
}

method defined {
    Red::AST::IsDefined.new: self
}

method args {}

method not { Red::AST::Not.new: self }
