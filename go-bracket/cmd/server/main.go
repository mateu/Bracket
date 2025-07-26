package main

import (
	"log"
	"os"

	"bracket/internal/database"
	"bracket/internal/handlers"
	"bracket/internal/middleware"

	"github.com/gin-gonic/gin"
)

func main() {
	// Initialize database
	dbConfig := database.Config{
		Driver:   getEnv("DB_DRIVER", "sqlite"),
		Host:     getEnv("DB_HOST", "localhost"),
		Port:     getEnv("DB_PORT", "5432"),
		User:     getEnv("DB_USER", "bracket"),
		Password: getEnv("DB_PASSWORD", ""),
		DBName:   getEnv("DB_NAME", "bracket.db"),
		SSLMode:  getEnv("DB_SSLMODE", "disable"),
	}

	if err := database.Initialize(dbConfig); err != nil {
		log.Fatal("Failed to initialize database:", err)
	}

	// Initialize Gin router
	r := gin.Default()

	// Add middleware
	r.Use(middleware.CORSMiddleware())

	// Initialize handlers
	authHandler := handlers.NewAuthHandler()
	bracketHandler := handlers.NewBracketHandler()

	// Public routes
	public := r.Group("/api/v1")
	{
		public.POST("/auth/login", authHandler.Login)
		public.POST("/auth/register", authHandler.Register)
		public.GET("/bracket", bracketHandler.GetBracket)
		public.GET("/teams", bracketHandler.GetTeams)
		public.GET("/regions", bracketHandler.GetRegions)
		public.GET("/leaderboard", bracketHandler.GetLeaderboard)
	}

	// Protected routes (require authentication)
	protected := r.Group("/api/v1")
	protected.Use(middleware.AuthMiddleware())
	{
		protected.GET("/auth/profile", authHandler.GetProfile)
		protected.GET("/bracket/player/:player_id", bracketHandler.GetPlayerBracket)
		protected.POST("/bracket/pick", bracketHandler.CreatePick)
	}

	// Admin routes
	admin := r.Group("/api/v1/admin")
	admin.Use(middleware.AuthMiddleware(), middleware.AdminMiddleware())
	{
		admin.PUT("/bracket/game/:game_id/result", bracketHandler.UpdateGameResult)
	}

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	// Start server
	port := getEnv("PORT", "8080")
	log.Printf("Starting server on port %s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}

// getEnv gets an environment variable with a default value
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

