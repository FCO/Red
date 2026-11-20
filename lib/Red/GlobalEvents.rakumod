use v6;
use Red::Class;
use Red::Event;

=head2 Red::GlobalEvents

#| Registry and listener bootstrap shared by global-notifiable models.
unit module Red::GlobalEvents;

my %MODELS;
my %LISTENERS;
my %WARNED;
my $LOCK = Lock.new;

#| Register a model declared with C<is global-notifiable>.
our sub register-model(Mu:U $model) is export {
    $LOCK.protect: { %MODELS{$model.^name} = $model }
}

#| Every global-notifiable model known in this process.
our sub global-models(--> Array:D) is export {
    $LOCK.protect: { %MODELS.values.Array }
}

#| Resolve the model named by a notification payload.
our sub model-for-name(Str:D $name) is export {
    $LOCK.protect: { %MODELS{$name} }
}

our sub supports(Mu $driver --> Bool:D) is export {
    so $driver.defined
        && $driver.^can('supports-global-events')
        && $driver.supports-global-events
}

#| Warn once per model/backend when a notification was requested but is unavailable.
our sub warn-unsupported(Mu:U $model, Mu $driver) is export {
    my $backend = $driver.defined ?? $driver.driver-name !! '<no driver>';
    my $key = $model.^name ~ '|' ~ $backend;
    $LOCK.protect: {
        unless %WARNED{$key}++ {
            warn "Model {$model.^name} is global-notifiable but $backend does not "
                ~ 'support global events; using local events';
        }
    }
}

#| Turn a backend notification into a Red::Event delivered by the listening driver.
our sub on-global-notification(Mu $driver, %payload) is export {
    return unless (%payload<v> // 1).Str eq '1';
    my $name = %payload<model>;
    return unless $name.defined;
    my $model = model-for-name($name);
    return if $model =:= Any || $model =:= Mu;

    my %raw-ids = %payload<ids> // {};
    my @columns = try $model.^global-notification-columns // [];
    my @attrs   = try $model.^global-notification-ids // [];
    my %attr-for = @columns.kv.map: -> $i, $column { $column => @attrs[$i] };
    my %ids = %raw-ids.kv.map: -> $column, $value {
        (%attr-for{$column} // $column) => $value
    };
    return unless %ids;

    my %metadata = %payload<metadata> // {};
    %metadata<protocol> //= %payload<v> // 1;
    $driver.emit: Red::Event.new:
        :$model,
        :global,
        :%ids,
        :%metadata,
        :materialize-origin(-> {
            my $*RED-DB = $driver;
            $model.^find(|%ids)
        });
}

#| Make sure a driver has one listener for all global-notifiable models.
our sub ensure-global-listener(Mu $driver, @models = global-models) is export {
    my $guard = $driver.?transaction-guard;
    my $base = $guard.defined ?? $guard.driver !! $driver;
    my $target = $base.global-event-listener-driver;
    return Nil unless supports($target) && @models;
    my $key = try $target.connection-id // $target.^name;
    $LOCK.protect: {
        unless %LISTENERS{$key}:exists {
            my &callback = -> %payload { on-global-notification($target, %payload) };
            %LISTENERS{$key} = $target.listen-global-events(@models.Array, &callback) // True;
        }
    }
}

#| Public entry point: start listening for global notifications on a driver.
our sub start-global-events(Mu :$with!) is export {
    ensure-global-listener($with, global-models)
}
