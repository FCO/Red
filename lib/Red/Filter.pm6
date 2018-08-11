enum Red::Op << merge eq ne lt gt le ge like ilike not cast >>;
unit class Red::Filter;

has Red::Op $.op;
has List    $.args;
has List    $.bind;

multi method WHICH(::?CLASS:D:) { "{self.^name}|$!op|{$!args>>.WHICH}|{$!bind>>.WHICH}" }

multi method WHICH(::?CLASS:U:) { "{self.^name}" }

multi method perl(::?CLASS:U:) { "{self.^name}" }

multi method perl(::?CLASS:D:) { "{self.^name}.new(:op({$!op}), :args({$!args.perl}), :bind({$!bind.perl}))" }

multi method merge(::?CLASS:U: ::?CLASS:D $filter) { $filter }

multi method merge(::?CLASS:D: ::?CLASS:D $filter) {
    ::?CLASS.new: :op(merge), :args(self, $filter)
}
