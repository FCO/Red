use Red:api<2>;

model Sentence {
    has UInt $.id          is id;
    has Str  $.lang        is column;
    has Str  $.sentence    is column;
    has Int  @.links-to    is relationship(*.id-to, :model<Link>);
    has Int  @.links-from  is relationship(*.id-from, :model<Link>);

    multi method translate(::CLASS:D: :to($lang)) {
        $.links-from.map(*.to-sentence.first(*.lang eq $lang).sentence).Seq.first: so *
    }
    multi method translate(::CLASS:U: $sentence, :from($lang) = "eng", :$to) {
        self.^all.first({ .sentence eq $sentence && .lang eq $lang }).translate: :$to
    }

    method ^populate($model) {
        for "t/sentences.csv".IO.lines {
            $model.^create: |(<id lang sentence> Z=> .split: "\t").Hash
        }
    }
}
