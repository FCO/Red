sub kebab-to-snake-case($_) is export { S:g/'-'/_/ }
sub camel-to-snake-case($_) is export { kebab-to-snake-case lc S:g/(\w)<?before <[A..Z]>>/$0_/ }
