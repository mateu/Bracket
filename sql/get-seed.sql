DELIMITER $$
---USE bracket_2023$$
DROP FUNCTION IF EXISTS `get_winner_seed`$$
CREATE FUNCTION `get_winner_seed`(given_game INT) RETURNS INT(11)
DETERMINISTIC
BEGIN   
    SET @teamSeed = 
    (
    	select team.seed
	from pick
	join team
	on pick.pick = team.id
	where player = 1
	and game = given_game
    );   
    RETURN @teamSeed;
END$$
DELIMITER ;

