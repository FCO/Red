use Red::Utils;
use Red::Model;
use Red::AST;
use Red::AST::Unary;
use Red::AST::IsDefined;
unit class Red::Column does Red::AST;

has Attribute   $.attr is required;
has Str         $.attr-name        = $!attr.name.substr: 2;
has Bool        $.id               = False;
has Bool        $.auto-increment   = False;
has             &.references;
has             &!actual-references;
has             $!ref;
has Bool        $.nullable         = $!attr.package.HOW.?default-nullable($!attr.package) // False;
has Str         $.name             = kebab-to-snake-case self.attr.name.substr: 2;
has Str         $.name-alias       = $!name;
has Str         $.type;
has             &.inflate          = *.self;
has             &.deflate          = *.self;
has             $.computation;
has Str         $.model-name;
has Str         $.column-name;
has Str         $.require          = $!model-name;

class ReferencesProxy does Callable {
    has Str     $.model-name    is required;
    has Str     $.column-name;
    has Str     $.require       = $!model-name;
    has         $.model;
    has         &.references;
    has Bool    $!tried-model   = False;

    method model( --> Mu:U ) {
        if !$!tried-model {
            my $model = ::($!model-name);
            if !$model && $model ~~ Failure {
                require ::($!require);
                $model = ::($!model-name);
            }
            $!model = $model;
            $!tried-model = True;
        }
        $!model;
    }

    method CALL-ME {
        if &!references {
            &!references.(self.model)
        }
        else {
            self.model."{ $!column-name }"()
        }
    }
}

method class { self.attr.package }

method references(--> Callable) is rw {
    &!actual-references //= do {
        if &!references {
            if $!model-name {
                ReferencesProxy.new(:&!references, :$!model-name, :$!require);
            }
            else {
                &!references;
            }
        }
        elsif $!model-name && $!column-name {
            ReferencesProxy.new(:$!model-name, :$!column-name, :$!require);
        }
        else {
            Callable
        }
    }
}

method ref {
    $!ref //= .() with self.references
}

method returns { $!attr.package }

method transpose(&func) { func self }

method gist { "{$!attr.package.^as}.{$!name-alias}" }

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
    self.clone: attr-name => $name, :$name, id => False, :$nullable, attr => Attribute
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
