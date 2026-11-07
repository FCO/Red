CREATE TABLE "comment" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "body" text NOT NULL,
    "task_id" integer,
    FOREIGN KEY ("task_id") REFERENCES "task" ("id")
);
