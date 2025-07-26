use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "regions")]
pub struct Model {
    #[sea_orm(primary_key)]
    pub id: i32,
    #[sea_orm(unique)]
    pub name: String,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(has_many = "super::team::Entity")]
    Teams,
    #[sea_orm(has_many = "super::game::Entity")]
    Games,
}

impl Related<super::team::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Teams.def()
    }
}

impl Related<super::game::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Games.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}

pub use Entity as RegionEntity;

