from typing import List, Dict, Any, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from sqlalchemy.orm import selectinload

from ..models import Game, Pick, Player, Team, Region, Tournament


class TournamentService:
    """Service for tournament-related operations."""
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def get_bracket_status(self) -> Dict[str, Any]:
        """Get the current bracket status."""
        # Get active tournament
        result = await self.db.execute(
            select(Tournament).where(Tournament.is_active == True)
        )
        tournament = result.scalar_one_or_none()
        
        if not tournament:
            return {"error": "No active tournament"}
        
        # Get all games with teams
        games_result = await self.db.execute(
            select(Game)
            .options(
                selectinload(Game.team1),
                selectinload(Game.team2),
                selectinload(Game.winner),
                selectinload(Game.region)
            )
            .order_by(Game.round, Game.id)
        )
        games = games_result.scalars().all()
        
        # Get all regions
        regions_result = await self.db.execute(select(Region))
        regions = regions_result.scalars().all()
        
        return {
            "tournament": {
                "id": tournament.id,
                "year": tournament.year,
                "name": tournament.name,
                "picks_locked": tournament.picks_locked,
                "is_active": tournament.is_active
            },
            "games": [
                {
                    "id": game.id,
                    "round": game.round,
                    "region": game.region.name if game.region else None,
                    "team1": {
                        "id": game.team1.id,
                        "name": game.team1.name,
                        "seed": game.team1.seed
                    } if game.team1 else None,
                    "team2": {
                        "id": game.team2.id,
                        "name": game.team2.name,
                        "seed": game.team2.seed
                    } if game.team2 else None,
                    "winner": {
                        "id": game.winner.id,
                        "name": game.winner.name,
                        "seed": game.winner.seed
                    } if game.winner else None,
                    "point_value": game.point_value,
                    "completed": game.is_completed
                }
                for game in games
            ],
            "regions": [
                {
                    "id": region.id,
                    "name": region.name
                }
                for region in regions
            ]
        }
    
    async def calculate_player_score(self, player_id: int) -> int:
        """Calculate total score for a player."""
        result = await self.db.execute(
            select(func.sum(Game.point_value))
            .select_from(Pick)
            .join(Game, Pick.game_id == Game.id)
            .where(
                and_(
                    Pick.player_id == player_id,
                    Pick.pick_id == Game.winner_id
                )
            )
        )
        score = result.scalar()
        return score or 0
    
    async def get_leaderboard(self) -> List[Dict[str, Any]]:
        """Get the current leaderboard."""
        # Get all players with their scores
        result = await self.db.execute(
            select(
                Player,
                func.coalesce(func.sum(Game.point_value), 0).label('score')
            )
            .outerjoin(Pick, Pick.player_id == Player.id)
            .outerjoin(
                Game, 
                and_(
                    Pick.game_id == Game.id,
                    Pick.pick_id == Game.winner_id
                )
            )
            .where(Player.active == True)
            .group_by(Player.id)
            .order_by(func.coalesce(func.sum(Game.point_value), 0).desc())
        )
        
        leaderboard = []
        for player, score in result:
            leaderboard.append({
                "player": player,
                "score": score
            })
        
        return leaderboard
    
    async def update_game_result(self, game_id: int, winner_id: int) -> bool:
        """Update the result of a game."""
        # Get the game
        result = await self.db.execute(
            select(Game).where(Game.id == game_id)
        )
        game = result.scalar_one_or_none()
        
        if not game:
            raise ValueError("Game not found")
        
        # Verify the winner is one of the teams in the game
        if winner_id not in [game.team1_id, game.team2_id]:
            raise ValueError("Winner must be one of the teams in the game")
        
        # Update the game
        game.winner_id = winner_id
        await self.db.commit()
        
        return True
    
    async def can_make_pick(self, game_id: int) -> bool:
        """Check if picks can still be made for a game."""
        # Check if tournament picks are locked
        result = await self.db.execute(
            select(Tournament).where(Tournament.is_active == True)
        )
        tournament = result.scalar_one_or_none()
        
        if not tournament or tournament.picks_locked:
            return False
        
        # Check if game is already completed
        game_result = await self.db.execute(
            select(Game).where(Game.id == game_id)
        )
        game = game_result.scalar_one_or_none()
        
        if not game or game.is_completed:
            return False
        
        return True

