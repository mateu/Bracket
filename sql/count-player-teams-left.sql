with games_played as (
    select p.game, g.round
    from pick p
    join game g
    on p.game = g.id
    where p.player = 1
),
losing_teams as (
    select
    CASE 
        WHEN round > 1 THEN get_loser(game)
        ELSE get_first_round_loser(game)
        END as team
    from games_played
),
games_remaining as (
    select p.game
    from pick p
    where p.player = 24
    and p.game not in (select game from games_played)
),
player_teams_remaining as (
    select player, pick
    from pick
    where game in (select game from games_remaining)
    and pick not in (select team from losing_teams)
    group by player, pick
)
select player, count(*) as teams_left
from player_teams_remaining
group by player
;
