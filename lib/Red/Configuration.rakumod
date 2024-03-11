class Red::Configuration {
  has UInt  $.current-version                     = self!find-current-version;
  has UInt  %.model-current-version is default(0) = self!find-all-models-current-version;
  has UInt  $.dump-current-version                = self!find-dump-current-version;
  has IO()  $.base-path                           = $*CWD; # where *.add("META6.json") ~~ :f = $*CWD;
  has IO()  $.migration-base-path                 = $!base-path.add: "migrations";
  has IO()  $.dump-path                           = $!base-path.add: ".db-dumps";
  has IO()  $.model-storage-path                  = $!migration-base-path.add: "models";
  has IO()  $.version-storage-path                = $!migration-base-path.add: "versions";
  has IO()  $.dump-storage-path                   = $!migration-base-path.add: "dumps";
  has Str() $.red-subdir                          = "red";
  has Str() $.sql-subdir                          = "sql";
  has Str() @.drivers                             = <SQLite Pg>;

  has %!versions-cache                            = self!compute-version-cache;
  has %!models-cache                              = self!compute-models-cache;


  method !compute-version-cache {
    # TODO: Implement this
    note "prepare a hash with all migration versions";
    %()
  }
  method !compute-models-cache {
    # TODO: Implememt this
    note "prepare a hash with all model versions";
    %()
  }
  method !find-current-version {
    # TODO: Impment this
    note "find current version";
    0
  }
  method !find-all-models-current-version {
    # TODO: Impment this
    note "find all models current versions";
    %()
  }
  method !find-dump-current-version {
    # TODO: Impment this
    note "find dump current version";
    0
  }
  method !random-string  {
    # FIXME: make it right
    [|("a".."z"), |("A".."Z"), |(0..9)].roll(30).join
  }

  multi method version-path($version) {
   $!version-storage-path.add: $version
  }

  multi method version-path {
    $.version-path: $!current-version
  }

  method new-model-version(Str $model-name) {
    ++%!model-current-version{$model-name}
  }

  multi method model-path(Str() $model-name) {
    $.model-path: $model-name, %!model-current-version{$model-name}
  }

  multi method model-path(Str() $model-name, UInt $version) {
    $.model-version-path: $model-name, $version
  }

  multi method model-version-path(Str() $model-name, UInt() $version) {
    $!model-storage-path.add: %!models-cache{$model-name}{$version}
  }

  multi method model-version-path(Str() $model-name-version) {
    if $model-name-version ~~ /^$<name>=[<[\w:]>*\w] ":" ["ver<" ~ ">" $<ver>=[\d+]|\w+ "<" ~ ">" \w+]* % ":"/ {
      $.model-version-path: $<name>, $<ver> // 0
    }
  }

  multi method dump-version-path(UInt() $version) {
    $!dump-storage-path.add: $version
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
