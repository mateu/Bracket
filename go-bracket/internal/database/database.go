package database

import (
	"fmt"
	"log"

	"bracket/internal/models"

	"gorm.io/driver/postgres"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

type Config struct {
	Driver   string
	Host     string
	Port     string
	User     string
	Password string
	DBName   string
	SSLMode  string
}

var DB *gorm.DB

// Initialize sets up the database connection
func Initialize(config Config) error {
	var err error
	var dialector gorm.Dialector

	switch config.Driver {
	case "postgres":
		dsn := fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%s sslmode=%s",
			config.Host, config.User, config.Password, config.DBName, config.Port, config.SSLMode)
		dialector = postgres.Open(dsn)
	case "sqlite":
		dialector = sqlite.Open(config.DBName)
	default:
		return fmt.Errorf("unsupported database driver: %s", config.Driver)
	}

	DB, err = gorm.Open(dialector, &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})
	if err != nil {
		return fmt.Errorf("failed to connect to database: %w", err)
	}

	// Run migrations
	if err := models.AutoMigrate(DB); err != nil {
		return fmt.Errorf("failed to run migrations: %w", err)
	}

	// Seed initial data
	if err := seedInitialData(); err != nil {
		return fmt.Errorf("failed to seed initial data: %w", err)
	}

	log.Println("Database initialized successfully")
	return nil
}

// seedInitialData populates the database with initial tournament structure
func seedInitialData() error {
	// Check if regions already exist
	var count int64
	DB.Model(&models.Region{}).Count(&count)
	if count > 0 {
		return nil // Already seeded
	}

	// Create regions
	regions := []models.Region{
		{ID: 1, Name: "East"},
		{ID: 2, Name: "Midwest"},
		{ID: 3, Name: "South"},
		{ID: 4, Name: "West"},
	}

	for _, region := range regions {
		if err := DB.Create(&region).Error; err != nil {
			return fmt.Errorf("failed to create region %s: %w", region.Name, err)
		}
	}

	// Create sample tournament
	tournament := models.Tournament{
		Year:        2024,
		Name:        "NCAA Men's Basketball Tournament 2024",
		IsActive:    true,
		PicksLocked: false,
	}

	if err := DB.Create(&tournament).Error; err != nil {
		return fmt.Errorf("failed to create tournament: %w", err)
	}

	log.Println("Initial data seeded successfully")
	return nil
}

// GetDB returns the database instance
func GetDB() *gorm.DB {
	return DB
}

