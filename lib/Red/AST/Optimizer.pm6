use Red::AST::Value;

sub is-same(\same, $_) { .?value === (same ?? True !! False)  }

role SameIfPresent[\same] {
    multi method optimize($ where &is-same.assuming(same), $) {
        ast-value same
    }

    multi method optimize($, $ where &is-same.assuming(same)) {
        ast-value same
    }
}

role SameIfTheOtherIsTrue {
    multi method optimize($ where &is-same.assuming(True), $ret) {
        $ret
    }

    multi method optimize($ret, $ where &is-same.assuming(True)) {
        $ret
    }
}
