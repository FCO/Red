use Red::Config;

sub EXPORT {
    red-config
        :schema<Post Person>,
        :database(database "SQLite"),
        :debug(so %*ENV<RED_DEBUG>),
        "refreshable",
}
