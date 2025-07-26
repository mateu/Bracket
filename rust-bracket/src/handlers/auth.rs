use axum::{
    extract::State,
    http::StatusCode,
    response::Json,
};
use sea_orm::{ActiveModelTrait, ColumnTrait, EntityTrait, QueryFilter, Set};
use serde::{Deserialize, Serialize};
use validator::Validate;

use crate::{
    auth::{generate_token, hash_password, verify_password},
    models::player,
    AppState,
};

#[derive(Debug, Deserialize, Validate)]
pub struct LoginRequest {
    #[validate(length(min = 1))]
    pub login: String,
    #[validate(length(min = 1))]
    pub password: String,
}

#[derive(Debug, Deserialize, Validate)]
pub struct RegisterRequest {
    #[validate(length(min = 1))]
    pub login: String,
    #[validate(length(min = 6))]
    pub password: String,
    #[validate(length(min = 1))]
    pub first_name: String,
    #[validate(length(min = 1))]
    pub last_name: String,
    #[validate(email)]
    pub email: String,
}

#[derive(Debug, Serialize)]
pub struct AuthResponse {
    pub token: String,
    pub player: player::Model,
}

pub async fn login(
    State(state): State<AppState>,
    Json(payload): Json<LoginRequest>,
) -> Result<Json<AuthResponse>, StatusCode> {
    // Validate input
    if let Err(_) = payload.validate() {
        return Err(StatusCode::BAD_REQUEST);
    }

    // Find player by login
    let player = player::Entity::find()
        .filter(player::Column::Login.eq(&payload.login))
        .filter(player::Column::Active.eq(true))
        .one(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::UNAUTHORIZED)?;

    // Verify password
    if !verify_password(&payload.password, &player.password) {
        return Err(StatusCode::UNAUTHORIZED);
    }

    // Generate token
    let token = generate_token(&player).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(AuthResponse { token, player }))
}

pub async fn register(
    State(state): State<AppState>,
    Json(payload): Json<RegisterRequest>,
) -> Result<Json<AuthResponse>, StatusCode> {
    // Validate input
    if let Err(_) = payload.validate() {
        return Err(StatusCode::BAD_REQUEST);
    }

    // Check if login or email already exists
    let existing_player = player::Entity::find()
        .filter(
            player::Column::Login
                .eq(&payload.login)
                .or(player::Column::Email.eq(&payload.email)),
        )
        .one(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    if existing_player.is_some() {
        return Err(StatusCode::CONFLICT);
    }

    // Hash password
    let hashed_password = hash_password(&payload.password)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // Create new player
    let new_player = player::ActiveModel {
        login: Set(payload.login),
        password: Set(hashed_password),
        first_name: Set(payload.first_name),
        last_name: Set(payload.last_name),
        email: Set(payload.email),
        is_admin: Set(false),
        active: Set(true),
        ..Default::default()
    };

    let player = new_player
        .insert(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // Generate token
    let token = generate_token(&player).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(AuthResponse { token, player }))
}

pub async fn get_profile(
    State(state): State<AppState>,
    player_id: i32,
) -> Result<Json<player::Model>, StatusCode> {
    let player = player::Entity::find_by_id(player_id)
        .one(&state.db)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)?;

    Ok(Json(player))
}

