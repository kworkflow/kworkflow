INSERT INTO "pomodoro_report" ("tag","date","time","duration","description")
VALUES ('first tag', '2021-11-18', '16:53:00', 45, 'first description'),
('second tag', '2021-11-18', '10:52:45', 60, 'second description'),
('second tag', '2021-11-18', '10:54:10', 3600, 'second description 2'),
('third tag', '2021-11-17', '16:24:23', 600, 'third description'),
('third tag', '2021-09-18', '13:00:43', 1800, 'third description 2');

INSERT INTO "statistics_report" ("label_name","status","date","time","elapsed_time_in_secs")
VALUES ('build', 'failure', '2021-11-18', '16:53:25', 20),
('list', 'success', '2021-11-18', '10:53:00', 45),
('deploy', 'success', '2021-11-17', '16:33:22', 60),
('build', 'success', '2021-09-18', '13:00:43', 980);

INSERT INTO "config" ("name", "description", "path")
VALUES ('some_config', 'this is the test config', '/some/path/some_config');
