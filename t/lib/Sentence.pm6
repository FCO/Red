use Link;
use Red:api<2>;

model Sentence {
    has UInt $.id          is serial;
    has Str  $.lang        is column;
    has Str  $.sentence    is column;
    has      @.links-to    is relationship(*.id-to,   :model<Link>);
    has      @.links-from  is relationship(*.id-from, :model<Link>);

    multi method translate(::?CLASS:D: :to($lang)) {
        $.links-from.first(*.to-sentence.lang eq $lang).to-sentence
    }
    multi method translate(::?CLASS:U: $sentence, :from($lang) = "eng", :$to) {
        Link.^all.first({
            .from-sentence.sentence eq $sentence
                    && .from-sentence.lang eq $lang
                    && .to-sentence.lang eq $to
        })
                .to-sentence
    }

    method ^populate($model) {
        for "t/sentences.csv".IO.lines {
            $model.^create: |(<lang sentence> Z=> .split("\t").map({ /^\d+$/ ?? .Int !! .self })).Hash
        }
    }
}
