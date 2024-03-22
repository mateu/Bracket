with players_with_no_picks as (
  select player.id from player
  left join pick
  on player.id = pick.player
  where pick.player is null
)
update player
set active = 0
where player.id in (select * from players_with_no_picks)
;
