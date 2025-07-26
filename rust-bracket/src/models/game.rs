use chrono::{DateTime, Utc};
use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "games")]
pub struct Model {
    #[sea_orm(primary_key)]
    pub id: i32,
    pub round: i16,
    pub region_id: Option<i32>,
    pub team1_id: Option<i32>,
    pub team2_id: Option<i32>,
    pub winner_id: Option<i32>,
    pub point_value: i32,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(
        belongs_to = "super::region::Entity",
        from = "Column::RegionId",
        to = "super::region::Column::Id"
    )]
    Region,
    #[sea_orm(
        belongs_to = "super::team::Entity",
        from = "Column::Team1Id",
        to = "super::team::Column::Id"
    )]
    Team1,
    #[sea_orm(
        belongs_to = "super::team::Entity",
        from = "Column::Team2Id",
        to = "super::team::Column::Id"
    )]
    Team2,
    #[sea_orm(
        belongs_to = "super::team::Entity",
        from = "Column::WinnerId",
        to = "super::team::Column::Id"
    )]
    Winner,
    #[sea_orm(has_many = "super::pick::Entity")]
    Picks,
}

impl Related<super::region::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Region.def()
    }
}

impl Related<super::pick::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Picks.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}

pub use Entity as GameEntity;

