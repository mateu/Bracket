package tournament

import (
	"errors"
	"fmt"

	"bracket/internal/database"
	"bracket/internal/models"
)

// BracketService handles tournament bracket logic
type BracketService struct{}

// NewBracketService creates a new bracket service
func NewBracketService() *BracketService {
	return &BracketService{}
}

// CreateBracket initializes a tournament bracket with games
func (bs *BracketService) CreateBracket(tournamentID uint) error {
	db := database.GetDB()

	// Get all teams
	var teams []models.Team
	if err := db.Preload("Region").Find(&teams).Error; err != nil {
		return fmt.Errorf("failed to get teams: %w", err)
	}

	if len(teams) != 64 {
		return errors.New("tournament requires exactly 64 teams")
	}

	// Group teams by region
	regionTeams := make(map[uint][]models.Team)
	for _, team := range teams {
		regionTeams[team.RegionID] = append(regionTeams[team.RegionID], team)
	}

	// Create regional games (rounds 1-4)
	gameID := uint(1)
	for regionID, teams := range regionTeams {
		if len(teams) != 16 {
			return fmt.Errorf("region %d must have exactly 16 teams", regionID)
		}

		// Sort teams by seed for proper bracket pairing
		// In a real implementation, you'd sort by seed
		gameID = bs.createRegionalGames(teams, regionID, gameID)
	}

	// Create Final Four games (semi-finals and championship)
	bs.createFinalFourGames(gameID)

	return nil
}

// createRegionalGames creates games for a single region
func (bs *BracketService) createRegionalGames(teams []models.Team, regionID uint, startGameID uint) uint {
	db := database.GetDB()
	gameID := startGameID

	// Round 1: 16 teams -> 8 games
	round1Games := make([]models.Game, 8)
	for i := 0; i < 8; i++ {
		game := models.Game{
			ID:         gameID,
			Round:      1,
			RegionID:   &regionID,
			Team1ID:    &teams[i*2].ID,
			Team2ID:    &teams[i*2+1].ID,
			PointValue: 1,
		}
		round1Games[i] = game
		db.Create(&game)
		gameID++
	}

	// Round 2: 8 winners -> 4 games
	for i := 0; i < 4; i++ {
		game := models.Game{
			ID:         gameID,
			Round:      2,
			RegionID:   &regionID,
			PointValue: 2,
		}
		db.Create(&game)
		gameID++
	}

	// Round 3 (Sweet 16): 4 winners -> 2 games
	for i := 0; i < 2; i++ {
		game := models.Game{
			ID:         gameID,
			Round:      3,
			RegionID:   &regionID,
			PointValue: 4,
		}
		db.Create(&game)
		gameID++
	}

	// Round 4 (Elite 8): 2 winners -> 1 game (Regional Championship)
	game := models.Game{
		ID:         gameID,
		Round:      4,
		RegionID:   &regionID,
		PointValue: 8,
	}
	db.Create(&game)
	gameID++

	return gameID
}

// createFinalFourGames creates the Final Four and Championship games
func (bs *BracketService) createFinalFourGames(startGameID uint) {
	db := database.GetDB()

	// Final Four (2 games)
	for i := 0; i < 2; i++ {
		game := models.Game{
			ID:         startGameID + uint(i),
			Round:      5,
			RegionID:   nil, // No region for Final Four
			PointValue: 16,
		}
		db.Create(&game)
	}

	// Championship game
	championship := models.Game{
		ID:         startGameID + 2,
		Round:      6,
		RegionID:   nil,
		PointValue: 32,
	}
	db.Create(&championship)
}

// CalculatePlayerScore calculates a player's total score
func (bs *BracketService) CalculatePlayerScore(playerID uint) (uint, error) {
	db := database.GetDB()

	var totalScore uint
	var picks []models.Pick

	// Get all picks for the player
	if err := db.Preload("Game").Preload("Pick").Where("player_id = ?", playerID).Find(&picks).Error; err != nil {
		return 0, fmt.Errorf("failed to get player picks: %w", err)
	}

	// Calculate score for each correct pick
	for _, pick := range picks {
		if pick.Game.WinnerID != nil && *pick.Game.WinnerID == pick.PickID {
			totalScore += pick.Game.PointValue
		}
	}

	return totalScore, nil
}

// GetBracketStatus returns the current state of the tournament bracket
func (bs *BracketService) GetBracketStatus() (*BracketStatus, error) {
	db := database.GetDB()

	var games []models.Game
	if err := db.Preload("Team1").Preload("Team2").Preload("Winner").Preload("Region").Find(&games).Error; err != nil {
		return nil, fmt.Errorf("failed to get games: %w", err)
	}

	status := &BracketStatus{
		Games:         games,
		TotalGames:    len(games),
		CompletedGames: 0,
	}

	for _, game := range games {
		if game.WinnerID != nil {
			status.CompletedGames++
		}
	}

	return status, nil
}

// BracketStatus represents the current tournament status
type BracketStatus struct {
	Games          []models.Game `json:"games"`
	TotalGames     int           `json:"total_games"`
	CompletedGames int           `json:"completed_games"`
}

// UpdateGameResult updates the winner of a game
func (bs *BracketService) UpdateGameResult(gameID, winnerID uint) error {
	db := database.GetDB()

	// Verify the winner is one of the teams in the game
	var game models.Game
	if err := db.First(&game, gameID).Error; err != nil {
		return fmt.Errorf("game not found: %w", err)
	}

	if game.Team1ID == nil || game.Team2ID == nil {
		return errors.New("game teams not set")
	}

	if winnerID != *game.Team1ID && winnerID != *game.Team2ID {
		return errors.New("winner must be one of the teams in the game")
	}

	// Update the game result
	game.WinnerID = &winnerID
	if err := db.Save(&game).Error; err != nil {
		return fmt.Errorf("failed to update game result: %w", err)
	}

	// TODO: Advance winner to next round game
	// This would involve finding the next round game and setting the team

	return nil
}

