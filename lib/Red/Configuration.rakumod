use UUID;
class Red::Configuration {
  has IO()  $.base-path                           = $*CWD; # where *.add("META6.json") ~~ :f = $*CWD;
  has IO()  $.migration-base-path                 = $!base-path.add: "migrations";
  has IO()  $.dump-path                           = $!base-path.add: ".db-dumps";
  has IO()  $.model-storage-path                  = $!migration-base-path.add: "models";
  has IO()  $.version-storage-path                = $!migration-base-path.add: "versions";
  has IO()  $.dump-storage-path                   = $!migration-base-path.add: "dumps";
  has UInt  $.current-version                     = self!find-current-version;
  has       %.versions-cache                      = self!compute-version-cache;
  has       %.models-cache                        = self!compute-models-cache;
  has UInt  %.model-current-version is default(0) = self!find-all-models-current-version;
  has UInt  $.dump-current-version                = self!find-dump-current-version;
  has Str() $.red-subdir                          = "red";
  has Str() $.sql-subdir                          = "sql";
  has Str() @.drivers                             = <SQLite Pg>;


  method !compute-version-cache {
    # TODO: Implement this
    note "prepare a hash with all migration versions";
    %()
  }
  method !compute-models-cache {
    my %cache;
    note "prepare a hash with all model versions";
    with $!model-storage-path {
      .mkdir;
      for .dir.grep: *.basename ne ".precomp" -> $file {
        if $file.slurp ~~ /model <.ws> $<model>=[[\w|"::"|"-"]+ ":ver<" ~ ">" $<version>=[\d+]]/ {
          %cache{$<model>} = $file
        }
      }
    }
    say %cache;
    %cache
  }
  method !find-current-version {
    # TODO: Impment this
    note "find current version";
    0
  }
  method !find-all-models-current-version {
    my %ver;
    note "find all models current versions";
    %!models-cache.keys>>.split(/":ver<"/)>>.list.classify(*.head, :as{ .tail.chop.Int }).kv.map(-> $k, @v { $k => @v.max }).Hash;
  }

  method !find-dump-current-version(-->UInt()) {
    $!dump-storage-path.mkdir;
    note "find dump current version";
    $!dump-storage-path.dir.map(*.basename.subst(/\.\w+/, "").Int).max max 0
  }

  method copy-model(IO() $file) {
    my UInt $ver;
    my $code = $file.slurp.subst:
      /model <.ws> $<model-name>=[[\w|"::"|"-"]+]/,
      -> $/ {
        $ver //= $.new-model-version: $<model-name>;
        "model { ~$<model-name> }:ver<{ $ver }>"
      }
    ;
    $.model-version-path($<model-name>, $ver).spurt: $code
  }

  multi method version-path($version) {
   $!version-storage-path.add: $version
  }

  multi method version-path {
    $.version-path: $!current-version
  }

  method new-model-version(Str() $model-name) {
    LEAVE {
      my $key = "{ $model-name }:ver<{ %!model-current-version{$model-name} }>";
      %!models-cache{$key} //= $!model-storage-path.add(~UUID.new).extension: "rakumod"
    }
    ++%!model-current-version{$model-name}
  }

  method new-model-path(Str $model-name) {
    $.model-path: $model-name, $.new-model-version: $model-name
  }

  multi method model-path(Str() $model-name) {
    say %!model-current-version;
    $.model-path: $model-name, %!model-current-version{$model-name}
  }

  multi method model-path(Str() $model-name, UInt $version) {
    $.model-version-path: $model-name, $version
  }

  multi method model-version-path(Str() $model-name, UInt() $version) {
    say %!models-cache;
    say $version;
    my $key = "{ $model-name }:ver<{ $version }>";
    %!models-cache{$key}
  }

  multi method model-version-path(Str() $model-name-version) {
    if $model-name-version ~~ /^$<name>=[<[\w:]>*\w] ":" ["ver<" ~ ">" $<ver>=[\d+]|\w+ "<" ~ ">" \w+]* % ":"/ {
      $.model-version-path: $<name>, $<ver> // 0
    }
  }

  multi method dump-version-path(UInt() $version) {
    $!dump-storage-path.add($version).extension: "sql"
  }

  multi method dump-version-path {
    $.dump-version-path: $!dump-current-version
  }

  multi method new-dump-version-path {
    $.dump-version-path: ++$!dump-current-version
  }

  multi method migration-red-path {
    $.version-path.add($!red-subdir)
  }

  multi method migration-red-path(UInt $version) {
    $.version-path($version).add($!red-subdir)
  }

  multi method migration-sql-path(Str $driver where @!drivers.one) {
    $.version-path.add($!sql-subdir).add: $driver
  }

  multi method migration-sql-path(Str $driver where @!drivers.one, UInt $version) {
    $.version-path($version).add($!sql-subdir).add: $driver
  }
}

use Configuration Red::Configuration;
