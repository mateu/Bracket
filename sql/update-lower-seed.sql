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
set lower_seed = 1, game.winner = get_winner(game.id)
where game.id in (select * from lower_seed_games)
;

--- For other rounds we'll use the getter functions
--- to find how who the teams involved are since
--- we don't know that up front like we do for round 1
with games_played as (
    select pick.game, team.seed
    from pick
    join team
    on pick.pick = team.id
    where pick.player = 1
)
update game
inner join games_played gp
on game.id = gp.game
set lower_seed = CASE
  WHEN game.round > 1 THEN (get_winner_seed(game.id) > get_loser_seed(game.id))
  # First round is deterministic based on seed
  ELSE gp.seed > 8
  END
  , game.winner = get_winner(game.id)
;
