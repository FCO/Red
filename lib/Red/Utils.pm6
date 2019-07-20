sub snake-to-kebab-case($_) is export { S:g/'_'/-/ }
sub kebab-to-snake-case($_) is export { S:g/'-'/_/ }
sub camel-to-snake-case($_) is export { kebab-to-snake-case lc S:g/(\w)<?before <[A..Z]>>/$0_/ }
sub camel-to-kebab-case($_) is export { lc S:g/(\w)<?before <[A..Z]>>/$0-/ }
sub kebab-to-camel-case($_) is export { S:g/"-"(\w)/{$0.uc}/ with .wordcase }
sub snake-to-camel-case($_) is export { S:g/"_"(\w)/{$0.uc}/ with .wordcase }
