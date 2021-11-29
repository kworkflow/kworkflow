INSERT INTO tags (tag)
VALUES ('first tag'), ('second tag'), ('third tag'), ('fourth tag');

INSERT INTO pomodoro (tag_id,dt_start,dt_end,descript)
VALUES (1, '2021-11-18 16:53:00', '2021-11-18 16:53:45', 'first description'),
(2, '2021-11-18 10:52:45', '2021-11-18 10:53:45', 'second description'),
(2, '2021-11-18 10:54:10', '2021-11-18 10:55:45', 'second description 2'),
(3, '2021-11-17 16:24:23', '2021-11-17 16:34:22', 'third description'),
(4, '2021-09-18 13:00:43', '2021-09-18 14:00:43', 'fourth description');

INSERT INTO statistic (label,dt_start,dt_end)
VALUES ('build_failure', '2021-11-18 16:53:25', '2021-11-18 16:53:45'),
('list', '2021-11-18 10:53:00', '2021-11-18 10:53:45'),
('deploy', '2021-11-17 16:33:22', '2021-11-17 16:34:22'),
('build', '2021-09-18 13:00:43', '2021-09-18 14:00:43');
