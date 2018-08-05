enum Red::Op << eq ne lt gt le ge like ilike not >>;
unit class Red::Filter;

has Red::Op $.op;
has         @.args;
has         @.bind;

method WHICH { "{self.^name}|$!op|@!args[]|@!bind[]" }
