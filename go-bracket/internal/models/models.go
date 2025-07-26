package models

import (
	"time"

	"gorm.io/gorm"
)

// Region represents the four tournament regions
type Region struct {
	ID   uint   `json:"id" gorm:"primaryKey"`
	Name string `json:"name" gorm:"unique;not null"`
}

// Team represents a tournament team
type Team struct {
	ID       uint   `json:"id" gorm:"primaryKey"`
	Seed     uint8  `json:"seed" gorm:"not null"`
	Name     string `json:"name" gorm:"unique;not null"`
	RegionID uint   `json:"region_id" gorm:"not null"`
	URL      string `json:"url"`
	Region   Region `json:"region" gorm:"foreignKey:RegionID"`
}

// Player represents a user/player in the system
type Player struct {
	ID        uint      `json:"id" gorm:"primaryKey"`
	Login     string    `json:"login" gorm:"unique;not null"`
	Password  string    `json:"-" gorm:"not null"` // Hidden from JSON
	FirstName string    `json:"first_name" gorm:"not null"`
	LastName  string    `json:"last_name" gorm:"not null"`
	Email     string    `json:"email" gorm:"unique;not null"`
	IsAdmin   bool      `json:"is_admin" gorm:"default:false"`
	Active    bool      `json:"active" gorm:"default:true"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// Game represents a tournament game
type Game struct {
	ID       uint  `json:"id" gorm:"primaryKey"`
	Round    uint8 `json:"round" gorm:"not null"`
	RegionID *uint `json:"region_id"` // Null for Final Four and Championship
	Team1ID  *uint `json:"team1_id"`
	Team2ID  *uint `json:"team2_id"`
	WinnerID *uint `json:"winner_id"`
	
	// Relationships
	Region *Region `json:"region,omitempty" gorm:"foreignKey:RegionID"`
	Team1  *Team   `json:"team1,omitempty" gorm:"foreignKey:Team1ID"`
	Team2  *Team   `json:"team2,omitempty" gorm:"foreignKey:Team2ID"`
	Winner *Team   `json:"winner,omitempty" gorm:"foreignKey:WinnerID"`
	
	// Scoring weight for this game (higher rounds worth more)
	PointValue uint `json:"point_value" gorm:"default:1"`
}

// Pick represents a player's prediction for a game
type Pick struct {
	ID       uint   `json:"id" gorm:"primaryKey"`
	PlayerID uint   `json:"player_id" gorm:"not null"`
	GameID   uint   `json:"game_id" gorm:"not null"`
	PickID   uint   `json:"pick_id" gorm:"not null"` // Team ID they picked to win
	
	// Relationships
	Player Player `json:"player" gorm:"foreignKey:PlayerID"`
	Game   Game   `json:"game" gorm:"foreignKey:GameID"`
	Pick   Team   `json:"pick" gorm:"foreignKey:PickID"`
	
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// RegionScore tracks player scores by region
type RegionScore struct {
	ID       uint `json:"id" gorm:"primaryKey"`
	PlayerID uint `json:"player_id" gorm:"not null"`
	RegionID uint `json:"region_id" gorm:"not null"`
	Points   uint `json:"points" gorm:"default:0"`
	
	// Relationships
	Player Player `json:"player" gorm:"foreignKey:PlayerID"`
	Region Region `json:"region" gorm:"foreignKey:RegionID"`
}

// Session represents user sessions
type Session struct {
	ID        string    `json:"id" gorm:"primaryKey"`
	PlayerID  uint      `json:"player_id" gorm:"not null"`
	Data      string    `json:"data"`
	ExpiresAt time.Time `json:"expires_at"`
	CreatedAt time.Time `json:"created_at"`
	
	// Relationships
	Player Player `json:"player" gorm:"foreignKey:PlayerID"`
}

// Tournament represents tournament metadata
type Tournament struct {
	ID          uint      `json:"id" gorm:"primaryKey"`
	Year        uint      `json:"year" gorm:"unique;not null"`
	Name        string    `json:"name" gorm:"not null"`
	StartDate   time.Time `json:"start_date"`
	EndDate     time.Time `json:"end_date"`
	IsActive    bool      `json:"is_active" gorm:"default:false"`
	PicksLocked bool      `json:"picks_locked" gorm:"default:false"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// AutoMigrate runs database migrations
func AutoMigrate(db *gorm.DB) error {
	return db.AutoMigrate(
		&Region{},
		&Team{},
		&Player{},
		&Game{},
		&Pick{},
		&RegionScore{},
		&Session{},
		&Tournament{},
	)
}

