use Red:api<2>;

model Link {
    has UInt $.id-from       is column{:id, :references(*.id), :model-name<Sentence>};
    has UInt $.id-to         is column{:id, :references(*.id), :model-name<Sentence>};
    has      $.to-sentence   is relationship(*.id-to  , :model<Sentence>);
    has      $.from-sentence is relationship(*.id-from, :model<Sentence>);

    method ^populate($model) {
        for "t/links.csv".IO.lines {
            $model.^create: |(<id-from id-to> Z=> .split("\t")>>.Int).Hash
        }
    }
}
