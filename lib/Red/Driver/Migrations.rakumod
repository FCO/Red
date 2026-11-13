use X::Red::Migration;

#| Backend hooks used by the migration coordinator and offline planner.
unit role Red::Driver::Migrations;

method migration-error(Str $reason) { X::Red::Migration.new(:$reason).throw }
method migration-transactional-ddl(--> Bool:D) { False }
method migration-nontransactional-ddl(--> Bool:D) { False }
method migration-session { (self, Any) }
method migration-validate-column($table, $before, $column) { }
method migration-normalize-table($table) { $table }
method migration-create-table-prefix($table --> Array:D) { [] }
method migration-drop-table-suffix($table --> Array:D) { [] }
method migration-auto-column($column, Str $table --> List:D) {
    self.migration-error('Automatic migration columns are unsupported by this driver')
}
method migration-drop-index(Str $table, Str $index --> Str:D) {
    'DROP INDEX ' ~ self.table-name-wrapper($index)
}
method migration-alter-column(Str $table, $before, $column, Str $definition --> Array:D) {
    self.migration-error('Column alteration is unsupported by this driver')
}
method migration-lock(Bool :$read-only = False) {
    self.migration-error('Migration locking is unsupported by this driver')
}
method migration-unlock { }
method migration-read-transaction(--> Bool:D) { False }
method migration-rebuild-nullability(--> Bool:D) { False }
method migration-release-for-child(--> Bool:D) { False }
method migration-close { }
method migration-extra-drop-statements(@tables --> Array:D) { [] }
method migration-string-literal(Str $value --> Str:D) {
    self.migration-error('Escaped string literals are unsupported by this driver')
}
method migration-sql-options(--> Hash:D) {
    %(hash-comment => False, dash-comment-whitespace => False,
        reject-hint-comment => False, dollar-quotes => False)
}
method migration-provision(IO::Path $folder, Str $name, %server --> Hash:D) {
    self.migration-error('Temporary databases are unsupported by this driver')
}
method migration-drop-temporary($admin, Str $name) { }
method migration-finish-unexecuted(--> Bool:D) { False }

#| True when acquiring the migration lock also starts the write transaction.
method migration-lock-transaction(--> Bool:D) { False }
