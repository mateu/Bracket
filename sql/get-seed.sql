DELIMITER $$
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

DELIMITER $$
DROP FUNCTION IF EXISTS `get_loser_seed`$$
CREATE FUNCTION `get_loser_seed`(given_game INT) RETURNS INT(11)
DETERMINISTIC
BEGIN
    SET @teamSeed =

    (
select team.seed
from team
    join (
        select *
        from pick
        where pick.player = 1
            and pick.game in (
                select parent_game
                from game_graph
                join pick
                on game_graph.game = pick.game
                where pick.game = given_game
                    and pick.player = 1
            )
    ) picks on team.id = picks.pick
where picks.pick not in (
        select pick.pick
        from team
            join (
                select *
                from pick
                where pick.player = 1
                    and pick.game in (
                        select parent_game
                        from game_graph
                            join pick on game_graph.game = pick.game
                        where pick.game = given_game
                            and pick.player = 1
                    )
            ) picks on team.id = picks.pick
            join pick on picks.pick = pick.pick
        where pick.game = given_game
            and pick.player = 1
    )
    );

    RETURN @teamSeed;
END$$
DELIMITER ;
