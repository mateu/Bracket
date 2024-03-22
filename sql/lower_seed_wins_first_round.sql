with lower_seed_games as (
    select game.id game
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