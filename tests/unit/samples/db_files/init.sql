CREATE TABLE IF NOT EXISTS "tags"(
	"id" INTEGER PRIMARY KEY,
	"tag" TEXT UNIQUE
);

CREATE TABLE IF NOT EXISTS "pomodoro"(
	"tag_id" INTEGER NOT NULL,
	"start_date" TEXT NOT NULL,
	"start_time" TEXT NOT NULL,
	"duration" INTEGER NOT NULL,
	"description" TEXT,
	FOREIGN KEY("tag_id") REFERENCES "tags"("id")
);

CREATE TABLE IF NOT EXISTS "statistics"(
	"name" TEXT NOT NULL,
	"start_date" TEXT NOT NULL,
	"start_time" TEXT,
	"execution_time" INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS "fake_table" (
  "id" INTEGER NOT NULL UNIQUE,
  "name" TEXT NOT NULL UNIQUE,
  "attribute1" TEXT,
  "attribute2" TEXT,
  PRIMARY KEY("id")
);

CREATE TABLE IF NOT EXISTS "groups" (
    "id" INTEGER NOT NULL UNIQUE,
    "name" VARCHAR(50) NOT NULL UNIQUE,
    PRIMARY KEY("id")
);

CREATE TABLE IF NOT EXISTS "contacts" (
    "id" INTEGER NOT NULL UNIQUE,
    "name" VARCHAR(100) NOT NULL,
    "email" VARCHAR(100) NOT NULL,
    PRIMARY KEY("id")
);

CREATE TABLE IF NOT EXISTS "contact_group" (
    "contact_id" SERIAL INTEGER,
    "group_id" INTEGER,
    PRIMARY KEY ("contact_id", "group_id"),
    FOREIGN KEY ("contact_id") REFERENCES "contacts"("id"),
    FOREIGN KEY ("group_id") REFERENCES "groups"("id")
);
