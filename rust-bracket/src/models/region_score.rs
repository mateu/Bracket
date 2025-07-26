use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "region_scores")]
pub struct Model {
    #[sea_orm(primary_key)]
    pub id: i32,
    pub player_id: i32,
    pub region_id: i32,
    pub points: i32,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(
        belongs_to = "super::player::Entity",
        from = "Column::PlayerId",
        to = "super::player::Column::Id"
    )]
    Player,
    #[sea_orm(
        belongs_to = "super::region::Entity",
        from = "Column::RegionId",
        to = "super::region::Column::Id"
    )]
    Region,
}

impl Related<super::player::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Player.def()
    }
}

impl Related<super::region::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Region.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}

pub use Entity as RegionScoreEntity;

