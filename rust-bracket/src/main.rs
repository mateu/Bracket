use axum::{
    extract::{Path, State},
    http::StatusCode,
    middleware,
    response::Json,
    routing::{get, post, put},
    Router,
};
use sea_orm::DatabaseConnection;
use std::env;
use tower::ServiceBuilder;
use tower_http::{cors::CorsLayer, trace::TraceLayer};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

mod auth;
mod database;
mod handlers;
mod middleware as app_middleware;
mod models;
mod tournament;

#[derive(Clone)]
pub struct AppState {
    pub db: DatabaseConnection,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize tracing
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "rust_bracket=debug,tower_http=debug".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    // Load environment variables
    dotenvy::dotenv().ok();

    // Database connection
    let database_url = env::var("DATABASE_URL")
        .unwrap_or_else(|_| "sqlite://bracket.db".to_string());

    let db = database::establish_connection(&database_url).await?;

    // Seed initial data
    database::seed_initial_data(&db).await?;

    let state = AppState { db };

    // Build our application with routes
    let app = Router::new()
        // Public routes
        .route("/api/v1/auth/login", post(handlers::auth::login))
        .route("/api/v1/auth/register", post(handlers::auth::register))
        .route("/api/v1/bracket", get(handlers::bracket::get_bracket))
        .route("/api/v1/teams", get(handlers::bracket::get_teams))
        .route("/api/v1/regions", get(handlers::bracket::get_regions))
        .route("/api/v1/leaderboard", get(handlers::bracket::get_leaderboard))
        // Protected routes
        .route(
            "/api/v1/auth/profile",
            get(|State(state): State<AppState>, request: axum::extract::Request| async move {
                let claims = request.extensions().get::<auth::Claims>().unwrap();
                handlers::auth::get_profile(State(state), claims.player_id).await
            }),
        )
        .route(
            "/api/v1/bracket/player/:player_id",
            get(handlers::bracket::get_player_bracket),
        )
        .route(
            "/api/v1/bracket/pick",
            post(|State(state): State<AppState>, request: axum::extract::Request, Json(payload): Json<handlers::bracket::CreatePickRequest>| async move {
                let claims = request.extensions().get::<auth::Claims>().unwrap();
                handlers::bracket::create_pick(State(state), claims.player_id, Json(payload)).await
            }),
        )
        .route_layer(middleware::from_fn_with_state(
            state.clone(),
            app_middleware::auth::auth_middleware,
        ))
        // Admin routes
        .route(
            "/api/v1/admin/bracket/game/:game_id/result",
            put(handlers::bracket::update_game_result),
        )
        .route_layer(middleware::from_fn(
            app_middleware::auth::admin_middleware,
        ))
        .route_layer(middleware::from_fn_with_state(
            state.clone(),
            app_middleware::auth::auth_middleware,
        ))
        // Health check
        .route("/health", get(|| async { Json(serde_json::json!({"status": "ok"})) }))
        .layer(
            ServiceBuilder::new()
                .layer(TraceLayer::new_for_http())
                .layer(CorsLayer::permissive()),
        )
        .with_state(state);

    // Run the server
    let port = env::var("PORT").unwrap_or_else(|_| "3000".to_string());
    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{}", port)).await?;

    tracing::info!("Server running on port {}", port);

    axum::serve(listener, app).await?;

    Ok(())
}

