use anyhow::Result;
use sea_orm::{Database, DatabaseConnection, DbErr};
use tracing::info;

use crate::models::{region, tournament};

pub async fn establish_connection(database_url: &str) -> Result<DatabaseConnection, DbErr> {
    let db = Database::connect(database_url).await?;
    info!("Database connection established");
    Ok(db)
}

pub async fn seed_initial_data(db: &DatabaseConnection) -> Result<()> {
    use sea_orm::{ActiveModelTrait, EntityTrait, Set};

    // Check if regions already exist
    let region_count = region::Entity::find().count(db).await?;
    if region_count > 0 {
        return Ok(());
    }

    // Create regions
    let regions = vec![
        region::ActiveModel {
            id: Set(1),
            name: Set("East".to_string()),
        },
        region::ActiveModel {
            id: Set(2),
            name: Set("Midwest".to_string()),
        },
        region::ActiveModel {
            id: Set(3),
            name: Set("South".to_string()),
        },
        region::ActiveModel {
            id: Set(4),
            name: Set("West".to_string()),
        },
    ];

    for region in regions {
        region.insert(db).await?;
    }

    // Create sample tournament
    let tournament = tournament::ActiveModel {
        year: Set(2024),
        name: Set("NCAA Men's Basketball Tournament 2024".to_string()),
        is_active: Set(true),
        picks_locked: Set(false),
        ..Default::default()
    };

    tournament.insert(db).await?;

    info!("Initial data seeded successfully");
    Ok(())
}

