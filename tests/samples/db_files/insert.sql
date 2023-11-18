INSERT INTO "tags" ("tag")
VALUES ('first tag'), ('second tag'), ('third tag'), ('fourth tag');

INSERT INTO "pomodoro" ("tag_id","start_date","start_time","duration","description")
VALUES (1, '2021-11-18', '16:53:00', 45, 'first description'),
(2, '2021-11-18', '10:52:45', 60, 'second description'),
(2, '2021-11-18', '10:54:10', 3600, 'second description 2'),
(3, '2021-11-17', '16:24:23', 600, 'third description'),
(3, '2021-09-18', '13:00:43', 1800, 'third description 2');

INSERT INTO "statistics" ("name","start_date","start_time","execution_time")
VALUES ('build_failure', '2021-11-18', '16:53:25', 20),
('list', '2021-11-18', '10:53:00', 45),
('deploy', '2021-11-17', '16:33:22', 60),
('build', '2021-09-18', '13:00:43', 980);
