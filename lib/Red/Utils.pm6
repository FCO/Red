#| Accepts a string and converts snake case (`foo_bar`) into kebab case (`foo-bar`)
sub snake-to-kebab-case($_) is export { S:g/'_'/-/ }
#| Accepts a string and converts kebab case (`foo-bar`) into snake case (`foo_bar`)
sub kebab-to-snake-case($_) is export { S:g/'-'/_/ }
#| Accepts a string and converts camel case (`fooBar`) into snake case (`foo_bar`)
sub camel-to-snake-case($_) is export { kebab-to-snake-case lc S:g/(\w)<?before <[A..Z]>>/$0_/ }
#| Accepts a string and converts camel case (`fooBar`) into kebab case (`foo-bar`)
sub camel-to-kebab-case($_) is export { lc S:g/(\w)<?before <[A..Z]>>/$0-/ }
#| Accepts a string and converts kebab case (`foo-bar`) into camel case (`fooBar`)
sub kebab-to-camel-case($_) is export { S:g/"-"(\w)/{$0.uc}/ with .wordcase }
#| Accepts a string and converts snake case (`foo_bar`) into camel case (`fooBar`)
sub snake-to-camel-case($_) is export { S:g/"_"(\w)/{$0.uc}/ with .wordcase }
