use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::Json,
};
use sea_orm::{ActiveModelTrait, ColumnTrait, EntityTrait, QueryFilter, Set};
use serde::{Deserialize, Serialize};
use validator::Validate;

use crate::{
    models::{game, pick, player, region, team, tournament},
    tournament::BracketService,
    AppState,
};

#[derive(Debug, Deserialize, Validate)]
pub struct CreatePickRequest {
    pub game_id: i32,
    pub team_id: i32,
}

#[derive(Debug, Deserialize, Validate)]
pub struct UpdateGameResultRequest {
    pub winner_id: i32,
}

#[derive(Debug, Serialize)]
pub struct PlayerBracketResponse {
    pub picks: Vec<pick::Model>,
    pub score: i32,
}

#[derive(Debug, Serialize)]
pub struct LeaderboardEntry {
    pub player: player::Model,
    pub score: i32,
}

pub async fn get_bracket(
    State(state): State<AppState>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let bracket_service = BracketService::new(state.db.clone());
    let status = bracket_service
        .get_bracket_status()
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(serde_json::to_value(status).unwrap()))
}

pub async fn get_player_bracket(
    State(state): State<AppState>,
    Path(player_id): Path<i32>,
) -> Result<Json<PlayerBracketResponse>, StatusCode> {
    // Get player's picks
    let picks = pick::Entity::find()
        .filter(pick::Column::PlayerId.eq(player_id))
        .all(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // Calculate score
    let bracket_service = BracketService::new(state.db.clone());
    let score = bracket_service
        .calculate_player_score(player_id)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(PlayerBracketResponse { picks, score }))
}

pub async fn create_pick(
    State(state): State<AppState>,
    player_id: i32,
    Json(payload): Json<CreatePickRequest>,
) -> Result<Json<pick::Model>, StatusCode> {
    // Validate input
    if let Err(_) = payload.validate() {
        return Err(StatusCode::BAD_REQUEST);
    }

    // Check if tournament picks are locked
    let tournament = tournament::Entity::find()
        .filter(tournament::Column::IsActive.eq(true))
        .one(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::BAD_REQUEST)?;

    if tournament.picks_locked {
        return Err(StatusCode::FORBIDDEN);
    }

    // Verify the game exists and the team is valid for that game
    let game = game::Entity::find_by_id(payload.game_id)
        .one(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)?;

    // Check if team is valid for this game
    if let (Some(team1_id), Some(team2_id)) = (game.team1_id, game.team2_id) {
        if payload.team_id != team1_id && payload.team_id != team2_id {
            return Err(StatusCode::BAD_REQUEST);
        }
    }

    // Check if pick already exists, update if so
    if let Some(existing_pick) = pick::Entity::find()
        .filter(pick::Column::PlayerId.eq(player_id))
        .filter(pick::Column::GameId.eq(payload.game_id))
        .one(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
    {
        // Update existing pick
        let mut pick_active: pick::ActiveModel = existing_pick.into();
        pick_active.pick_id = Set(payload.team_id);
        let updated_pick = pick_active
            .update(&state.db)
            .await
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
        return Ok(Json(updated_pick));
    }

    // Create new pick
    let new_pick = pick::ActiveModel {
        player_id: Set(player_id),
        game_id: Set(payload.game_id),
        pick_id: Set(payload.team_id),
        ..Default::default()
    };

    let pick = new_pick
        .insert(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(pick))
}

pub async fn update_game_result(
    State(state): State<AppState>,
    Path(game_id): Path<i32>,
    Json(payload): Json<UpdateGameResultRequest>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let bracket_service = BracketService::new(state.db.clone());
    bracket_service
        .update_game_result(game_id, payload.winner_id)
        .await
        .map_err(|_| StatusCode::BAD_REQUEST)?;

    Ok(Json(serde_json::json!({"message": "Game result updated successfully"})))
}

pub async fn get_leaderboard(
    State(state): State<AppState>,
) -> Result<Json<Vec<LeaderboardEntry>>, StatusCode> {
    let bracket_service = BracketService::new(state.db.clone());
    let leaderboard = bracket_service
        .get_leaderboard()
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let response: Vec<LeaderboardEntry> = leaderboard
        .into_iter()
        .map(|entry| LeaderboardEntry {
            player: entry.player,
            score: entry.score,
        })
        .collect();

    Ok(Json(response))
}

pub async fn get_teams(
    State(state): State<AppState>,
) -> Result<Json<Vec<team::Model>>, StatusCode> {
    let teams = team::Entity::find()
        .all(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(teams))
}

pub async fn get_regions(
    State(state): State<AppState>,
) -> Result<Json<Vec<region::Model>>, StatusCode> {
    let regions = region::Entity::find()
        .all(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(regions))
}

