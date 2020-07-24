use Test;

plan :skip-all("Different driver setted ($_)") with %*ENV<RED_DATABASE>;

lives-ok {
    use Red:api<2>;

    model Ingredient {
        has Str         $.name      is column;
        has Str         $.unit      is column;
    }

    my $*RED-DB = database "SQLite";
    Ingredient.^create-table;

    my $ingredient = Ingredient.^create:
            :name("Banana"),
            :unit("Unit");
}

done-testing;
