DELIMITER $$
CREATE FUNCTION game_winner_seed(
	game int
) 
RETURNS int
DETERMINISTIC
BEGIN
    DECLARE seed int;

    IF game > 8 THEN
		SET seed = 1;
    ELSEIF (game >= 11 AND 
			game <= 15) THEN
        SET seed = 2;
    END IF;
	    -- return the seed
	    RETURN (seed);
END$$
DELIMITER ;

DELIMITER //
CREATE FUNCTION getDob(emp_name VARCHAR(50))
   RETURNS DATE
   DETERMINISTIC
   BEGIN
      declare dateOfBirth DATE;
      select DOB into dateOfBirth from test.emp where 
	  Name = emp_name; MySQL CREATE FUNCTION Statement
         return dateOfBirth;
   END//
DELIMITER ;

CREATE FUNCTION game_winner_seed(game int)
RETURNS int
DETERMINISTIC
RETURN select team.seed
from team
    join (
        select *
        from pick
        where pick.player = 1
            and pick.game in (
                select mom_game game
                from game_graph
                    join pick on game_graph.game = pick.game
                where pick.game = 15
                    and pick.player = 1
                UNION
                select dad_game game
                from game_graph
                    join pick on game_graph.game = pick.game
                where pick.game = 15
                    and pick.player = 1
            )
    ) picks on team.id = picks.pick
where picks.pick in (
        select pick.pick
        from team
            join (
                select *
                from pick
                where pick.player = 1
                    and pick.game in (
                        select mom_game game
                        from game_graph
                            join pick on game_graph.game = pick.game
                        where pick.game = 15
                            and pick.player = 1
                        UNION
                        select dad_game game
                        from game_graph
                            join pick on game_graph.game = pick.game
                        where pick.game = 15
                            and pick.player = 1
                    )
            ) picks on team.id = picks.pick
            join pick on picks.pick = pick.pick
        where pick.game = 15
            and pick.player = 1
    );

DROP FUNCTION IF EXISTS game_winner_seed;
CREATE FUNCTION game_winner_seed(game int)
RETURNS int
DETERMINISTIC
BEGIN
  DECLARE seed INT;
  SET seed = (select 1);
  RETURN seed;
END$$

CREATE FUNCTION test (i CHAR)
 RETURNS VARCHAR(SIZE)
 NOT DETERMINISTIC
 BEGIN
  DECLARE select_var VARCHAR(SIZE);
  SET select_var = (SELECT name FROM team WHERE id = i);
  RETURN select_var;
 END$$

DELIMITER $$
USE `bracket_2023`$$
DROP FUNCTION IF EXISTS `fnGetActiveEventId`$$
CREATE DEFINER=`root`@`%` FUNCTION `fnGetActiveEventId`() RETURNS INT(11)
DETERMINISTIC
BEGIN   
    SET @eventId = (SELECT id FROM `team` LIMIT 1);   
    RETURN @eventId;
    END$$
DELIMITER ;

DELIMITER $$
USE `bracket_2023`$$
DROP FUNCTION IF EXISTS `fnGetWinnerSeed`$$
CREATE FUNCTION `fnGetWinnerSeed`() RETURNS INT(11)
DETERMINISTIC
BEGIN   
    SET @teamSeed = (SELECT id FROM `team` LIMIT 1);   
    RETURN @teamSeed;
END$$
DELIMITER ;