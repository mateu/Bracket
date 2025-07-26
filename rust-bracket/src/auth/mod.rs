use anyhow::Result;
use bcrypt::{hash, verify, DEFAULT_COST};
use chrono::{Duration, Utc};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};

use crate::models::player;

const JWT_SECRET: &[u8] = b"your-secret-key"; // In production, use environment variable

#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub player_id: i32,
    pub login: String,
    pub is_admin: bool,
    pub exp: i64,
    pub iat: i64,
}

#[derive(Debug, thiserror::Error)]
pub enum AuthError {
    #[error("Invalid credentials")]
    InvalidCredentials,
    #[error("Token generation failed")]
    TokenGeneration,
    #[error("Token validation failed")]
    TokenValidation,
    #[error("Password hashing failed")]
    PasswordHashing,
}

pub fn hash_password(password: &str) -> Result<String, AuthError> {
    hash(password, DEFAULT_COST).map_err(|_| AuthError::PasswordHashing)
}

pub fn verify_password(password: &str, hash: &str) -> bool {
    verify(password, hash).unwrap_or(false)
}

pub fn generate_token(player: &player::Model) -> Result<String, AuthError> {
    let now = Utc::now();
    let expiration = now + Duration::hours(24);

    let claims = Claims {
        player_id: player.id,
        login: player.login.clone(),
        is_admin: player.is_admin,
        exp: expiration.timestamp(),
        iat: now.timestamp(),
    };

    encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(JWT_SECRET),
    )
    .map_err(|_| AuthError::TokenGeneration)
}

pub fn validate_token(token: &str) -> Result<Claims, AuthError> {
    let token_data = decode::<Claims>(
        token,
        &DecodingKey::from_secret(JWT_SECRET),
        &Validation::default(),
    )
    .map_err(|_| AuthError::TokenValidation)?;

    Ok(token_data.claims)
}

