DROP TABLE IF EXISTS child;
DROP TABLE IF EXISTS parent;

CREATE TABLE parent (  
  `id` INT NOT NULL,
  `name` varchar(16) NOT NULL,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=INNODB;

CREATE TABLE child ( 
	`id` INT  NOT NULL,
  	`seed` tinyint(3) unsigned NOT NULL,
  	`name` varchar(32) NOT NULL,
	region INT NOT NULL,
    INDEX (region),
    FOREIGN KEY (region) REFERENCES parent(id),
  	PRIMARY KEY  (`id`),
  	UNIQUE KEY `team` (`name`)
) ENGINE=INNODB;