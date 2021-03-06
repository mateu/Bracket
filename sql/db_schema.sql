-- phpMyAdmin SQL Dump
-- version 2.9.1.1-Debian-6
-- http://www.phpmyadmin.net
-- 
-- Servidor: localhost
-- Tiempo de generación: 18-03-2008 a las 09:52:00
-- Versión del servidor: 5.0.32
-- Versión de PHP: 5.2.0-8+etch10
-- 
-- Base de datos: `ncaa`
-- 

-- --------------------------------------------------------

-- 
-- Estructura de tabla para la tabla `region`
-- 
DROP TABLE IF EXISTS pick;
DROP TABLE IF EXISTS game;
DROP TABLE IF EXISTS team;
DROP TABLE IF EXISTS region;
CREATE TABLE `region` (
  `id` INT NOT NULL,
  `name` varchar(16) NOT NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=INNODB;

-- 
-- Volcar la base de datos para la tabla `region`
-- 

INSERT INTO `region` (`id`, `name`) VALUES 
(1, 'East'),
(2, 'Midwest'),
(3, 'South'),
(4, 'West');

-- --------------------------------------------------------

-- 
-- Estructura de tabla para la tabla `team`
-- 
CREATE TABLE `team` (
  `id` INT  NOT NULL,
  `seed` tinyint(3) unsigned NOT NULL,
  `name` varchar(32) NOT NULL,
  `region` INT NOT NULL,
  `url` varchar(128) NOT NULL,
  INDEX (region),
  FOREIGN KEY (region) REFERENCES region(id),
  PRIMARY KEY  (`id`),
  UNIQUE KEY `team` (`name`)
) ENGINE=INNODB;

-- 
-- Volcar la base de datos para la tabla `team`
-- 

INSERT INTO `team` (`id`, `seed`, `name`, `region`, `url`) VALUES 
(1, 1, 'North Carolina', 1, 'nav'),
(2, 16, 'Coppin St./Mt. St. Mary''s', 1, ''),
(3, 8, 'Indiana', 1, 'iai'),
(4, 9, 'Arkansas', 1, 'aas'),
(5, 5, 'Notre Dame', 1, 'nbf'),
(6, 12, 'George Mason', 1, 'gad'),
(7, 4, 'Washington St.', 1, 'wah'),
(8, 13, 'Winthrop', 1, 'way'),
(9, 6, 'Oklahoma', 1, 'oae'),
(10, 11, 'St. Joseph''s', 1, 'sbq'),
(11, 3, 'Louisville', 1, 'laq'),
(12, 14, 'Boise St.', 1, 'bal'),
(13, 7, 'Butler', 1, 'bav'),
(14, 10, 'South Alabama', 1, 'sbe'),
(15, 2, 'Tennessee', 1, 'tag'),
(16, 15, 'American', 1, 'aan'),
(17, 1, 'Kansas', 2, 'kaa'),
(18, 16, 'Portland St.', 2, 'pbe'),
(19, 8, 'UNLV', 2, 'naj'),
(20, 9, 'Kent St.', 2, 'kae'),
(21, 5, 'Clemson', 2, 'cbg'),
(22, 12, 'Villanova', 2, 'vae'),
(23, 4, 'Vanderbilt', 2, 'vac'),
(24, 13, 'Siena', 2, 'sas'),
(25, 6, 'USC', 2, 'uad'),
(26, 11, 'Kansas St.', 2, 'kab'),
(27, 3, 'Wisconsin', 2, 'wbg'),
(28, 14, 'CSU Fullerton', 2, 'fat'),
(29, 7, 'Gonzaga', 2, 'gaj'),
(30, 10, 'Davidson', 2, 'dad'),
(31, 2, 'Georgetown', 2, 'gae'),
(32, 15, 'UMBC', 2, 'mam'),
(33, 1, 'Memphis', 3, 'map'),
(34, 16, 'TX Arlington', 3, 'tao'),
(35, 8, 'Mississippi St.', 3, 'mbg'),
(36, 9, 'Oregon', 3, 'oaj'),
(37, 5, 'Michigan St.', 3, 'may'),
(38, 12, 'Temple', 3, 'tad'),
(39, 4, 'Pittsburgh', 3, 'pal'),
(40, 13, 'Oral Roberts', 3, 'oai'),
(41, 6, 'Marquette', 3, 'maf'),
(42, 11, 'Kentucky', 3, 'kaf'),
(43, 3, 'Stanford', 3, 'sca'),
(44, 14, 'Cornell', 3, 'cbr'),
(45, 7, 'Miami (FL)', 3, 'mav'),
(46, 10, 'St. Mary''s', 3, 'sbt'),
(47, 2, 'Texas', 3, 'tal'),
(48, 15, 'Austin Peay', 3, 'abf'),
(49, 1, 'UCLA', 4, 'uad'),
(50, 16, 'Miss. Valley St.', 4, 'mbe'),
(51, 8, 'BYU', 4, 'baw'),
(52, 9, 'Texas A&M', 4, 'tan'),
(53, 5, 'Drake', 4, 'dar'),
(54, 12, 'West. Kentucky', 4, 'wao'),
(55, 4, 'Connecticut', 4, 'cbp'),
(56, 13, 'San Diego', 4, 'sad'),
(57, 6, 'Purdue', 4, 'pau'),
(58, 11, 'Baylor', 4, 'bae'),
(59, 3, 'Xavier', 4, 'xaa'),
(60, 14, 'Georgia', 4, 'gaf'),
(61, 7, 'West Virginia', 4, 'wal'),
(62, 10, 'Arizona', 4, 'aaq'),
(63, 2, 'Duke', 4, 'dau'),
(64, 15, 'Belmont', 4, 'bab');

DROP TABLE IF EXISTS player;
CREATE TABLE `player` (
  `id` INT NOT NULL,
  `login` varchar(16) NOT NULL,
  `password` varchar(16) NOT NULL,
  `first_name` varchar(16) NOT NULL,
  `last_name` varchar(16) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=INNODB;


CREATE TABLE `game` (
  `id` INT NOT NULL,
  `winner` INT,
  INDEX (winner),
  FOREIGN KEY (winner) REFERENCES team(id),
  PRIMARY KEY  (`id`)
) ENGINE=INNODB;


CREATE TABLE `pick` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `player` INT NOT NULL,
  `game` INT NOT NULL,
  `pick` INT NOT NULL,
  INDEX (player),
  FOREIGN KEY (player) REFERENCES player(id),
  INDEX (game),
  FOREIGN KEY (game) REFERENCES game(id),
  INDEX (pick),
  FOREIGN KEY (pick) REFERENCES team(id),
  PRIMARY KEY  (`id`)
) ENGINE=INNODB;

-- 
-- Estructura de tabla para la tabla `regionscores`
-- 
CREATE TABLE `regionscores` (
  `id` INT  NOT NULL,
  `player` int NOT NULL,
  `region` int NOT NULL,
  `points` INT NOT NULL,
  INDEX (player),
  INDEX (region),
  FOREIGN KEY (player) REFERENCES player(id),
  FOREIGN KEY (region) REFERENCES region(id),
  PRIMARY KEY  (`id`)
) ENGINE=INNODB;
