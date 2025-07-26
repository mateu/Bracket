package handlers

import (
	"net/http"
	"strconv"

	"bracket/internal/database"
	"bracket/internal/models"
	"bracket/pkg/tournament"

	"github.com/gin-gonic/gin"
)

type BracketHandler struct {
	bracketService *tournament.BracketService
}

func NewBracketHandler() *BracketHandler {
	return &BracketHandler{
		bracketService: tournament.NewBracketService(),
	}
}

type CreatePickRequest struct {
	GameID uint `json:"game_id" binding:"required"`
	TeamID uint `json:"team_id" binding:"required"`
}

type UpdateGameResultRequest struct {
	WinnerID uint `json:"winner_id" binding:"required"`
}

// GetBracket returns the current tournament bracket
func (bh *BracketHandler) GetBracket(c *gin.Context) {
	status, err := bh.bracketService.GetBracketStatus()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, status)
}

// GetPlayerBracket returns a player's picks/bracket
func (bh *BracketHandler) GetPlayerBracket(c *gin.Context) {
	playerIDStr := c.Param("player_id")
	playerID, err := strconv.ParseUint(playerIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid player ID"})
		return
	}

	db := database.GetDB()
	var picks []models.Pick

	if err := db.Preload("Game").Preload("Pick").Where("player_id = ?", uint(playerID)).Find(&picks).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get player bracket"})
		return
	}

	// Calculate player's current score
	score, err := bh.bracketService.CalculatePlayerScore(uint(playerID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to calculate score"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"picks": picks,
		"score": score,
	})
}

// CreatePick allows a player to make a pick for a game
func (bh *BracketHandler) CreatePick(c *gin.Context) {
	playerID, exists := c.Get("player_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	var req CreatePickRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	db := database.GetDB()

	// Check if tournament picks are locked
	var tournament models.Tournament
	if err := db.Where("is_active = ?", true).First(&tournament).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No active tournament"})
		return
	}

	if tournament.PicksLocked {
		c.JSON(http.StatusForbidden, gin.H{"error": "Picks are locked for this tournament"})
		return
	}

	// Verify the game exists and the team is valid for that game
	var game models.Game
	if err := db.First(&game, req.GameID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Game not found"})
		return
	}

	// Check if team is valid for this game
	if game.Team1ID != nil && game.Team2ID != nil {
		if req.TeamID != *game.Team1ID && req.TeamID != *game.Team2ID {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Team is not playing in this game"})
			return
		}
	}

	// Check if pick already exists, update if so
	var existingPick models.Pick
	if err := db.Where("player_id = ? AND game_id = ?", playerID, req.GameID).First(&existingPick).Error; err == nil {
		// Update existing pick
		existingPick.PickID = req.TeamID
		if err := db.Save(&existingPick).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update pick"})
			return
		}
		c.JSON(http.StatusOK, existingPick)
		return
	}

	// Create new pick
	pick := models.Pick{
		PlayerID: playerID.(uint),
		GameID:   req.GameID,
		PickID:   req.TeamID,
	}

	if err := db.Create(&pick).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create pick"})
		return
	}

	c.JSON(http.StatusCreated, pick)
}

// UpdateGameResult updates the result of a game (admin only)
func (bh *BracketHandler) UpdateGameResult(c *gin.Context) {
	// Check if user is admin
	isAdmin, exists := c.Get("is_admin")
	if !exists || !isAdmin.(bool) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Admin access required"})
		return
	}

	gameIDStr := c.Param("game_id")
	gameID, err := strconv.ParseUint(gameIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid game ID"})
		return
	}

	var req UpdateGameResultRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := bh.bracketService.UpdateGameResult(uint(gameID), req.WinnerID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Game result updated successfully"})
}

// GetLeaderboard returns the current tournament leaderboard
func (bh *BracketHandler) GetLeaderboard(c *gin.Context) {
	db := database.GetDB()

	var players []models.Player
	if err := db.Where("active = ?", true).Find(&players).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get players"})
		return
	}

	type LeaderboardEntry struct {
		Player models.Player `json:"player"`
		Score  uint          `json:"score"`
	}

	var leaderboard []LeaderboardEntry

	for _, player := range players {
		score, err := bh.bracketService.CalculatePlayerScore(player.ID)
		if err != nil {
			continue // Skip players with calculation errors
		}

		leaderboard = append(leaderboard, LeaderboardEntry{
			Player: player,
			Score:  score,
		})
	}

	c.JSON(http.StatusOK, leaderboard)
}

// GetTeams returns all tournament teams
func (bh *BracketHandler) GetTeams(c *gin.Context) {
	db := database.GetDB()

	var teams []models.Team
	if err := db.Preload("Region").Find(&teams).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get teams"})
		return
	}

	c.JSON(http.StatusOK, teams)
}

// GetRegions returns all tournament regions
func (bh *BracketHandler) GetRegions(c *gin.Context) {
	db := database.GetDB()

	var regions []models.Region
	if err := db.Find(&regions).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get regions"})
		return
	}

	c.JSON(http.StatusOK, regions)
}

