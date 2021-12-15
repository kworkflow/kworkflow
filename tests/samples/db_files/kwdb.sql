PRAGMA foreign_keys = 'ON';
BEGIN TRANSACTION;
-- Tables
CREATE TABLE IF NOT EXISTS "command_label" (
  "id" INTEGER NOT NULL UNIQUE,
  "name" TEXT NOT NULL UNIQUE,
  PRIMARY KEY("id")
);

CREATE TABLE IF NOT EXISTS "config" (
  "id" INTEGER NOT NULL UNIQUE,
  "name" TEXT NOT NULL,
  "description" TEXT,
  "path" TEXT NOT NULL UNIQUE,
  PRIMARY KEY("id")
);

CREATE TABLE IF NOT EXISTS "event" (
  "id" INTEGER NOT NULL UNIQUE,
  "date" TEXT NOT NULL,
  "time" TEXT,
  PRIMARY KEY("id")
);

CREATE TABLE IF NOT EXISTS "executed" (
  "id" INTEGER NOT NULL UNIQUE,
  "command_label_id" INTEGER NOT NULL,
  "elapsed_time_in_secs" INTEGER NOT NULL,
  "status_id" INTEGER NOT NULL,
  PRIMARY KEY("id"),
  FOREIGN KEY("id") REFERENCES "event"("id")
    ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY("command_label_id") REFERENCES "command_label"("id")
    ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY("status_id") REFERENCES "status"("id")
    ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS "status" (
  "id" INTEGER NOT NULL UNIQUE,
  "name" TEXT NOT NULL UNIQUE,
  PRIMARY KEY("id")
);

CREATE TABLE IF NOT EXISTS "tag" (
  "id" INTEGER NOT NULL UNIQUE,
  "name" TEXT NOT NULL UNIQUE,
  PRIMARY KEY("id")
);

CREATE TABLE IF NOT EXISTS "timebox" (
  "id" INTEGER NOT NULL UNIQUE,
  "duration" INTEGER NOT NULL,
  "description" TEXT,
  "tag_id" INTEGER NOT NULL,
  PRIMARY KEY("id"),
  FOREIGN KEY("id") REFERENCES "event"("id")
    ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY("tag_id") REFERENCES "tag"("id")
    ON UPDATE CASCADE ON DELETE RESTRICT
);

-- Populate commands and status tables
INSERT OR IGNORE INTO "status" ("name") VALUES
  ('success'),
  ('failure'),
  ('interrupted');

INSERT OR IGNORE INTO "command_label" ("name") VALUES
  ('build'),
  ('deploy'),
  ('modules_deploy'),
  ('uninstall'),
  ('list');

-- Views
CREATE VIEW "active_timebox" AS
  SELECT "e_id" AS "id", "tag", "date", "time", "duration", "description"
  FROM (SELECT "id" AS "e_id", "date", "time" FROM "event" ORDER BY "date")
  JOIN "timebox" AS "t" ON "e_id" IS "t"."id"
  JOIN (SELECT "id" AS "t_id", "name" AS "tag" FROM "tag") ON "t_id" IS "t"."tag_id"
  WHERE CAST (strftime('%s',"date"||'T'||"time",'utc')+"duration" AS INTEGER) >= strftime('%s','now');

CREATE VIEW "pomodoro_report" AS
  SELECT "e_id" AS "id", "tag_id", "name" AS "tag", "date", "time", "duration", "description"
  FROM (SELECT "id" AS "e_id", "date", "time" FROM "event")
  JOIN "timebox" AS "t" ON "t"."id" IS "e_id"
  JOIN "tag" AS "g" ON "g"."id" IS "t"."tag_id";

CREATE VIEW "statistics_report" AS
  SELECT "e_id" AS "id", "name" AS "label_name", "status_name" AS "status", "date", "time", "elapsed_time_in_secs"
  FROM (SELECT "id" AS "e_id", "date", "time" FROM "event")
  JOIN "executed" AS "x" ON "x"."id" IS "e_id"
  JOIN "command_label" AS "c" ON "c"."id" IS "x"."command_label_id"
  JOIN (SELECT "id" AS "s_id", "name" AS "status_name" FROM "status") ON "s_id" IS "x"."status_id";

-- Indexes
CREATE INDEX IF NOT EXISTS "command_label_idx" ON "command_label" (
  "name" ASC,
  "id"
);

CREATE INDEX IF NOT EXISTS "tag_idx" ON "tag" (
  "name" ASC,
  "id"
);

CREATE INDEX IF NOT EXISTS "chronological_events" ON "event" (
  "date" ASC,
  "time" ASC,
  "id"
);

CREATE INDEX IF NOT EXISTS "exec_idx" ON "executed" (
  "command_label_id" ASC,
  "status_id" ASC,
  "elapsed_time_in_secs" DESC,
  "id"
);

CREATE INDEX IF NOT EXISTS "timebox_idx" ON "timebox" (
  "tag_id" ASC,
  "duration" DESC,
  "id",
  "description"
);

-- Triggers
CREATE TRIGGER "delete_pomodoro" INSTEAD OF DELETE ON "pomodoro_report"
  BEGIN
    DELETE FROM "timebox" WHERE "timebox"."id" IS "OLD"."id";
    DELETE FROM "event" WHERE "event"."id" IS "OLD"."id";
  END;

CREATE TRIGGER "delete_statistics" INSTEAD OF DELETE ON "statistics_report"
  BEGIN
    DELETE FROM "executed" WHERE "executed"."id" IS "OLD"."id";
    DELETE FROM "event" WHERE "event"."id" IS "OLD"."id";
  END;

CREATE TRIGGER "insert_pomodoro" INSTEAD OF INSERT ON "pomodoro_report"
  BEGIN
    INSERT OR IGNORE INTO "tag" ("name") VALUES ("NEW"."tag");

    INSERT INTO "event" ("date", "time") VALUES ("NEW"."date", "NEW"."time");

    INSERT INTO "timebox" ("id","duration","description","tag_id")
      VALUES(
        last_insert_rowid(),
        "NEW"."duration",
        "NEW"."description",
        (SELECT "id" FROM "tag" AS "g" WHERE "g"."name" IS "NEW"."tag")
      );
  END;

CREATE TRIGGER "insert_statistics" INSTEAD OF INSERT ON "statistics_report"
  BEGIN
    INSERT OR IGNORE INTO "command_label" ("name") VALUES ("NEW"."label_name");
    INSERT OR IGNORE INTO "status" ("name") VALUES ("NEW"."status");

    INSERT INTO "event" ("date", "time") VALUES ("NEW"."date", "NEW"."time");

    INSERT INTO "executed" ("id", "command_label_id", "status_id", "elapsed_time_in_secs")
      VALUES (
        last_insert_rowid(),
        (SELECT "id" FROM "command_label" AS "c" WHERE "c"."name" IS "NEW"."label_name"),
        (SELECT "id" FROM "status" AS "s" WHERE "s"."name" IS "NEW"."status"),
        "NEW"."elapsed_time_in_secs"
      );
  END;

COMMIT;
