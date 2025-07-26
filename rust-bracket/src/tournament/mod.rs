use anyhow::Result;
use sea_orm::{DatabaseConnection, EntityTrait, QueryFilter, ColumnTrait};
use serde::{Deserialize, Serialize};

use crate::models::{game, pick, player, team};

#[derive(Debug, Serialize, Deserialize)]
pub struct BracketStatus {
    pub games: Vec<game::Model>,
    pub total_games: usize,
    pub completed_games: usize,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct LeaderboardEntry {
    pub player: player::Model,
    pub score: i32,
}

pub struct BracketService {
    db: DatabaseConnection,
}

impl BracketService {
    pub fn new(db: DatabaseConnection) -> Self {
        Self { db }
    }

    pub async fn get_bracket_status(&self) -> Result<BracketStatus> {
        let games = game::Entity::find().all(&self.db).await?;
        let completed_games = games.iter().filter(|g| g.winner_id.is_some()).count();

        Ok(BracketStatus {
            total_games: games.len(),
            completed_games,
            games,
        })
    }

    pub async fn calculate_player_score(&self, player_id: i32) -> Result<i32> {
        let picks = pick::Entity::find()
            .filter(pick::Column::PlayerId.eq(player_id))
            .find_also_related(game::Entity)
            .all(&self.db)
            .await?;

        let mut total_score = 0;

        for (pick, game_opt) in picks {
            if let Some(game) = game_opt {
                if let Some(winner_id) = game.winner_id {
                    if winner_id == pick.pick_id {
                        total_score += game.point_value;
                    }
                }
            }
        }

        Ok(total_score)
    }

    pub async fn update_game_result(&self, game_id: i32, winner_id: i32) -> Result<()> {
        use sea_orm::{ActiveModelTrait, Set};

        // Get the game and verify the winner is valid
        let game = game::Entity::find_by_id(game_id)
            .one(&self.db)
            .await?
            .ok_or_else(|| anyhow::anyhow!("Game not found"))?;

        // Verify winner is one of the teams in the game
        if let (Some(team1_id), Some(team2_id)) = (game.team1_id, game.team2_id) {
            if winner_id != team1_id && winner_id != team2_id {
                return Err(anyhow::anyhow!("Winner must be one of the teams in the game"));
            }
        } else {
            return Err(anyhow::anyhow!("Game teams not set"));
        }

        // Update the game result
        let mut game_active: game::ActiveModel = game.into();
        game_active.winner_id = Set(Some(winner_id));
        game_active.update(&self.db).await?;

        Ok(())
    }

    pub async fn create_bracket(&self, _tournament_id: i32) -> Result<()> {
        // Get all teams
        let teams = team::Entity::find().all(&self.db).await?;

        if teams.len() != 64 {
            return Err(anyhow::anyhow!("Tournament requires exactly 64 teams"));
        }

        // Group teams by region
        let mut region_teams: std::collections::HashMap<i32, Vec<team::Model>> = 
            std::collections::HashMap::new();
        
        for team in teams {
            region_teams.entry(team.region_id).or_default().push(team);
        }

        // Create regional games (rounds 1-4)
        let mut game_id = 1;
        for (region_id, teams) in region_teams {
            if teams.len() != 16 {
                return Err(anyhow::anyhow!("Region {} must have exactly 16 teams", region_id));
            }

            game_id = self.create_regional_games(teams, region_id, game_id).await?;
        }

        // Create Final Four games
        self.create_final_four_games(game_id).await?;

        Ok(())
    }

    async fn create_regional_games(
        &self,
        teams: Vec<team::Model>,
        region_id: i32,
        start_game_id: i32,
    ) -> Result<i32> {
        use sea_orm::{ActiveModelTrait, Set};

        let mut game_id = start_game_id;

        // Round 1: 16 teams -> 8 games
        for i in 0..8 {
            let game = game::ActiveModel {
                id: Set(game_id),
                round: Set(1),
                region_id: Set(Some(region_id)),
                team1_id: Set(Some(teams[i * 2].id)),
                team2_id: Set(Some(teams[i * 2 + 1].id)),
                point_value: Set(1),
                ..Default::default()
            };
            game.insert(&self.db).await?;
            game_id += 1;
        }

        // Round 2: 8 winners -> 4 games
        for _ in 0..4 {
            let game = game::ActiveModel {
                id: Set(game_id),
                round: Set(2),
                region_id: Set(Some(region_id)),
                point_value: Set(2),
                ..Default::default()
            };
            game.insert(&self.db).await?;
            game_id += 1;
        }

        // Round 3 (Sweet 16): 4 winners -> 2 games
        for _ in 0..2 {
            let game = game::ActiveModel {
                id: Set(game_id),
                round: Set(3),
                region_id: Set(Some(region_id)),
                point_value: Set(4),
                ..Default::default()
            };
            game.insert(&self.db).await?;
            game_id += 1;
        }

        // Round 4 (Elite 8): 2 winners -> 1 game
        let game = game::ActiveModel {
            id: Set(game_id),
            round: Set(4),
            region_id: Set(Some(region_id)),
            point_value: Set(8),
            ..Default::default()
        };
        game.insert(&self.db).await?;
        game_id += 1;

        Ok(game_id)
    }

    async fn create_final_four_games(&self, start_game_id: i32) -> Result<()> {
        use sea_orm::{ActiveModelTrait, Set};

        // Final Four (2 games)
        for i in 0..2 {
            let game = game::ActiveModel {
                id: Set(start_game_id + i),
                round: Set(5),
                region_id: Set(None),
                point_value: Set(16),
                ..Default::default()
            };
            game.insert(&self.db).await?;
        }

        // Championship game
        let championship = game::ActiveModel {
            id: Set(start_game_id + 2),
            round: Set(6),
            region_id: Set(None),
            point_value: Set(32),
            ..Default::default()
        };
        championship.insert(&self.db).await?;

        Ok(())
    }

    pub async fn get_leaderboard(&self) -> Result<Vec<LeaderboardEntry>> {
        let players = player::Entity::find()
            .filter(player::Column::Active.eq(true))
            .all(&self.db)
            .await?;

        let mut leaderboard = Vec::new();

        for player in players {
            let score = self.calculate_player_score(player.id).await.unwrap_or(0);
            leaderboard.push(LeaderboardEntry { player, score });
        }

        // Sort by score descending
        leaderboard.sort_by(|a, b| b.score.cmp(&a.score));

        Ok(leaderboard)
    }
}

