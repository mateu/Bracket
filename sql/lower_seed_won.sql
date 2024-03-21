select 
  * 
from 
  team 
  join (
    select 
      * 
    from 
      pick 
    where 
      pick.player = 1 
      and pick.game in (
        select 
          mom_game game 
        from 
          game_graph 
          join pick on game_graph.game = pick.game 
        where 
          pick.game = 15 
          and pick.player = 1 
        UNION 
        select 
          dad_game game 
        from 
          game_graph 
          join pick on game_graph.game = pick.game 
        where 
          pick.game = 15 
          and pick.player = 1
      )
  ) picks on team.id = picks.pick 
where 
  picks.pick not in (
    select 
      pick.pick 
    from 
      team 
      join (
        select 
          * 
        from 
          pick 
        where 
          pick.player = 1 
          and pick.game in (
            select 
              mom_game game 
            from 
              game_graph 
              join pick on game_graph.game = pick.game 
            where 
              pick.game = 15 
              and pick.player = 1 
            UNION 
            select 
              dad_game game 
            from 
              game_graph 
              join pick on game_graph.game = pick.game 
            where 
              pick.game = 15 
              and pick.player = 1
          )
      ) picks on team.id = picks.pick 
      join pick on picks.pick = pick.pick 
    where 
      pick.game = 15 
      and pick.player = 1
  );
