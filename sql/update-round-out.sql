--- Do for round 1
update team
set round_out = 1
where team.id in (select get_first_round_loser(game.id) from game where game.round = 1)
;

--- Do for later rounds
with round_out_info as (
    select get_loser(game.id) as losing_team, game.round
    from team
        join pick on team.id = pick.pick
        join game on pick.game = game.id
    where pick.player = 1
    and round > 1
)
update team
inner join round_out_info roi on
    team.id = roi.losing_team
set round_out = roi.round
;
