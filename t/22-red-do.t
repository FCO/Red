use X::Red::Exceptions;
use Red \<red-do>;
use Red::Driver::SQLite;
use Test;

model Bla { has UInt $.id is serial }

throws-like {
    red-do {;}
}, X::Red::Do::DriverNotDefined, message => /<< default >>/;

throws-like {
    red-do "name" => {;}
}, X::Red::Do::DriverNotDefined, message => /<< name >>/;

throws-like {
    red-defaults :bla["SQLite", :default], :ble["Pg", :default];
}, X::Red::Do::DriverDefinedMoreThanOnce;

throws-like {
    Bla.^create-table
}, X::Red::RedDbNotDefined;

red-defaults :bla["SQLite", :default];

lives-ok {
    red-do {;}
}

lives-ok {
    red-do "default" => {;}
}

lives-ok {
    red-do "bla" => {;}
}

red-do
    {
        isa-ok $*RED-DB, Red::Driver::SQLite;
    },
    "default" => {
        isa-ok $*RED-DB, Red::Driver::SQLite;
    },
    "bla" => {
        isa-ok $*RED-DB, Red::Driver::SQLite;
    }
;

lives-ok {
    Bla.^create-table;
}, "Use default if it's set";

red-defaults;

dies-ok {
    Bla.^create-table;
}, "Undefined ok";

try require ::("Config::Parser::json");
if ::("Config::Parser::json") !~~ Nil {
    red-defaults-from-config("./t/test.json");

    red-do
        {
            isa-ok $*RED-DB, Red::Driver::SQLite;
        },
        "default" => {
            isa-ok $*RED-DB, Red::Driver::SQLite;
        },
        "bla" => {
            isa-ok $*RED-DB, Red::Driver::SQLite;
        }
    ;

    red-defaults;

    dies-ok {
        Bla.^create-table;
    }, "Undefined ok";

    throws-like {
        red-defaults-from-config;
    }, X::Red::Defaults::FromConfNotFound;

    "./.red.json".IO.spurt: "./t/test.json".IO.slurp;

    red-defaults-from-config;

    red-do
        {
            isa-ok $*RED-DB, Red::Driver::SQLite;
        },
        "default" => {
            isa-ok $*RED-DB, Red::Driver::SQLite;
        },
        "bla" => {
            isa-ok $*RED-DB, Red::Driver::SQLite;
        }
    ;

    "./.red.json".IO.unlink;
}

use Red::Driver::Cache;
use Red::Driver::Cache::Memory;

red-defaults
    bla   => \(database("SQLite", :database<./a.db>)),
    ble   => \(database("SQLite", :database<./b.db>)),
    cache => \(cache "Memory", "SQLite"),
;

red-do
    "bla" => {
        isa-ok $*RED-DB, Red::Driver::SQLite;
        is $*RED-DB.database, "./a.db";
    },
    "ble" => {
        isa-ok $*RED-DB, Red::Driver::SQLite;
        is $*RED-DB.database, "./b.db";
    },
    "cache" => {
        isa-ok $*RED-DB, Red::Driver::Cache::Memory;
    },
;

done-testing
