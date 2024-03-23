--- First round games have a determistic
--- way to tell if the lower seed won
--- simply if the seed is > 8
with lower_seed_games as (
    select game.id
    from team
        join pick on team.id = pick.pick
        join game on pick.game = game.id
    where pick.player = 1
        and game.round = 1
        and team.seed > 8
)
update game
set lower_seed = 1
where game.id in (select * from lower_seed_games)
;

--- For rounds 2-4 we'll use the getter functions
--- to find how who the teams involved are since
--- we don't know that up front like we for round 1
--- TODO: We could extend this to round 5, just
--- need to input the game_graph rows
with games_played as (
    select pick.game
    from pick
    where pick.player = 1
)
update game
set lower_seed = (get_winner_seed(game.id) > get_loser_seed(game.id))
where game.round in (2, 3, 4)
and game.id in (select * from games_played)
;
