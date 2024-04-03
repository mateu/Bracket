DELIMITER $$
DROP FUNCTION IF EXISTS `get_winner`$$
CREATE FUNCTION `get_winner`(given_game INT) RETURNS INT(11)
DETERMINISTIC
BEGIN
    SET @teamID =
    (
        select pick
	from pick
	where player = 1
	and game = given_game
    );
    RETURN @teamId;
END$$
DELIMITER ;

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
	with winner as (
		select get_winner(given_game)
	)
        select seed
        from pick p
        join game_graph gg
        on p.game = gg.parent_game
        join team t
        on p.pick = t.id
        where p.player = 1
        and gg.game = given_game
        and p.pick not in (select * from winner)
    );
    RETURN @teamSeed;
END$$
DELIMITER ;

DELIMITER $$
DROP FUNCTION IF EXISTS `get_loser`$$
CREATE FUNCTION `get_loser`(given_game INT) RETURNS INT(11)
DETERMINISTIC
BEGIN
    SET @teamId =
    (
	with winner as (
		select get_winner(given_game)
	)
        select pick
        from pick p
        join game_graph gg
        on p.game = gg.parent_game
        where p.player = 1
        and gg.game = given_game
        and p.pick not in (select * from winner)
    );
    RETURN @teamId;
END$$
DELIMITER ;

DELIMITER $$
DROP FUNCTION IF EXISTS `get_first_round_loser`$$
CREATE FUNCTION `get_first_round_loser`(given_game INT) RETURNS INT(11)
DETERMINISTIC
BEGIN
    SET @teamId =
    (
        select team
        from game_team_graph
        where game_team_graph.game = given_game
        and team <> get_winner(given_game)
    );
    RETURN @teamId;
END$$
DELIMITER ;

DELIMITER $$
DROP FUNCTION IF EXISTS `get_current_round`$$
CREATE FUNCTION `get_current_round`() RETURNS INT(11)
DETERMINISTIC
BEGIN
    SET @round =
    (
        select max(round)
	from game g
	join pick p
	on g.id = p.game
	where player = 1
    );
    RETURN @round;
END$$
DELIMITER ;
