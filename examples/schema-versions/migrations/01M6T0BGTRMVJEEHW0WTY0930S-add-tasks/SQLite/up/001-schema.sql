CREATE TABLE "task" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "title" text NOT NULL,
    "project_id" integer,
    FOREIGN KEY ("project_id") REFERENCES "project" ("id")
);
