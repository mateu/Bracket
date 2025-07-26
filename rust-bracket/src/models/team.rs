use chrono::{DateTime, Utc};
use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "teams")]
pub struct Model {
    #[sea_orm(primary_key)]
    pub id: i32,
    pub seed: i16,
    #[sea_orm(unique)]
    pub name: String,
    pub region_id: i32,
    pub url: Option<String>,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(
        belongs_to = "super::region::Entity",
        from = "Column::RegionId",
        to = "super::region::Column::Id"
    )]
    Region,
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

pub use Entity as TeamEntity;

