use Red;

model Project is table<project> {
    has Int $.id is serial;
    has Str $.name is column;
}
model Task is table<task> {
    has Int $.id is serial;
    has Str $.title is column;
    has Int $.project-id is referencing{ :model(Project), :column<id> };
}
model Comment is table<comment> {
    has Int $.id is serial;
    has Str $.body is column;
    has Int $.task-id is referencing{ :model(Task), :column<id> };
}
