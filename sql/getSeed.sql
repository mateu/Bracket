DELIMITER $$
USE bracket_2023$$
DROP FUNCTION IF EXISTS `fnGetWinnerSeed`$$
CREATE FUNCTION `fnGetWinnerSeed`(givenGame INT) RETURNS INT(11)
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
    )
    );   
    
    RETURN @teamSeed;
END$$
DELIMITER ;

DELIMITER $$
USE bracket_2023$$
DROP FUNCTION IF EXISTS `fnGetLoserSeed`$$
CREATE FUNCTION `fnGetLoserSeed`(givenGame INT) RETURNS INT(11)
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
                select mom_game game
                from game_graph
                    join pick on game_graph.game = pick.game
                where pick.game = givenGame
                    and pick.player = 1
                UNION
                select dad_game game
                from game_graph
                    join pick on game_graph.game = pick.game
                where pick.game = givenGame
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
                        select mom_game game
                        from game_graph
                            join pick on game_graph.game = pick.game
                        where pick.game = givenGame
                            and pick.player = 1
                        UNION
                        select dad_game game
                        from game_graph
                            join pick on game_graph.game = pick.game
                        where pick.game = givenGame
                            and pick.player = 1
                    )
            ) picks on team.id = picks.pick
            join pick on picks.pick = pick.pick
        where pick.game = givenGame
            and pick.player = 1
    )
    );   
    
    RETURN @teamSeed;
END$$
DELIMITER ;