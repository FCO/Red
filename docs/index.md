### Red ORM documentation

Welcome to Red ORM documentation.

#### Tutorials

If you are looking for tutorials, you can visit:

* [Beginner tutorial](api/tutorials/start)
* Relationships tutorial
* Red CLI
* Working with PostgreSQL
* Working with SQLite
* Red Cookbook

#### API documentation

If you are looking for pure API docs, here you go:

* [API Index page](API)

#### Wiki

More examples can be found at the project [Wiki](https://github.com/FCO/Red/wiki) page.

#### For developers

* [Red architecture](tutorials/architecture)
* How to create a new driver
* How to create a new cache

#### How to contribute to documentation

##### I want to document something

To document an entity of Red itself (class, operator,
routine etc), do it as Pod6 in the source file. For example, before:

```perl6
sub prefix:<Σ>( *@number-list ) is export {
    [+] @number-list
}
```

After:

```perl6
#| A prefix operator that sums numbers
#| It accepts an arbitrary length list of numbers and returns their sum
#| Example: say Σ (13, 16, 1); # 30
sub prefix:<Σ>( *@number-list ) is export {
    [+] @number-list
}
```

Then execute `perl6 tools/make-docs.p6` to generate documentation
pages with your symbols included.

If you want to add a tutorial, write it as Markdown and add to `docs`
directory of this repository.

##### I want to change existing documentation

Depending on what it is, the documentation might be generated or not.

* Try to run a search in the repository for a line you want to change, for example, `grep -R "bad typo" .`
* If you see more than two files, try to narrow your search pattern
* If you see two files found, most likely one will be corresponding to sources or generated Markdown documentation. Please, patch the documentation in sources and, after re-generating pages with `tools/make-docs.p6` script, send a PR.
* If you see a single file found, Markdown file with a tutorial or this introduction text, please, patch it and send a PR.
* When not sure, please, create a ticket at [Red bugtracker](https://github.com/FCO/Red/issues)

All pull requests are welcome!
