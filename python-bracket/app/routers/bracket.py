from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from pydantic import BaseModel
from typing import List, Dict, Any, Optional

from ..core.database import get_db
from ..models import Team, Region, Pick, Player, Game
from ..auth import get_current_user, get_current_admin_user
from ..tournament import TournamentService

router = APIRouter(prefix="/api/v1/bracket", tags=["bracket"])


class CreatePickRequest(BaseModel):
    game_id: int
    team_id: int


class UpdateGameResultRequest(BaseModel):
    winner_id: int


class TeamResponse(BaseModel):
    id: int
    seed: int
    name: str
    region_id: int
    url: Optional[str] = None

    class Config:
        from_attributes = True


class RegionResponse(BaseModel):
    id: int
    name: str

    class Config:
        from_attributes = True


class PickResponse(BaseModel):
    id: int
    player_id: int
    game_id: int
    pick_id: int

    class Config:
        from_attributes = True


class PlayerBracketResponse(BaseModel):
    picks: List[PickResponse]
    score: int


class LeaderboardEntry(BaseModel):
    player: Dict[str, Any]
    score: int


@router.get("/")
async def get_bracket(db: AsyncSession = Depends(get_db)):
    """Get the current tournament bracket."""
    tournament_service = TournamentService(db)
    return await tournament_service.get_bracket_status()


@router.get("/teams", response_model=List[TeamResponse])
async def get_teams(db: AsyncSession = Depends(get_db)):
    """Get all teams."""
    result = await db.execute(select(Team))
    teams = result.scalars().all()
    return teams


@router.get("/regions", response_model=List[RegionResponse])
async def get_regions(db: AsyncSession = Depends(get_db)):
    """Get all regions."""
    result = await db.execute(select(Region))
    regions = result.scalars().all()
    return regions


@router.get("/player/{player_id}", response_model=PlayerBracketResponse)
async def get_player_bracket(
    player_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: Player = Depends(get_current_user)
):
    """Get a player's bracket and score."""
    # Users can only view their own bracket unless they're admin
    if current_user.id != player_id and not current_user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to view this bracket"
        )
    
    # Get player's picks
    result = await db.execute(
        select(Pick).where(Pick.player_id == player_id)
    )
    picks = result.scalars().all()
    
    # Calculate score
    tournament_service = TournamentService(db)
    score = await tournament_service.calculate_player_score(player_id)
    
    return PlayerBracketResponse(
        picks=[PickResponse.from_orm(pick) for pick in picks],
        score=score
    )


@router.post("/pick", response_model=PickResponse)
async def create_pick(
    pick_data: CreatePickRequest,
    db: AsyncSession = Depends(get_db),
    current_user: Player = Depends(get_current_user)
):
    """Create or update a pick for the current user."""
    tournament_service = TournamentService(db)
    
    # Check if picks can be made
    if not await tournament_service.can_make_pick(pick_data.game_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Picks are locked or game is completed"
        )
    
    # Verify the game exists and the team is valid for that game
    game_result = await db.execute(
        select(Game).where(Game.id == pick_data.game_id)
    )
    game = game_result.scalar_one_or_none()
    
    if not game:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Game not found"
        )
    
    # Check if team is valid for this game
    if game.team1_id and game.team2_id:
        if pick_data.team_id not in [game.team1_id, game.team2_id]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Team is not playing in this game"
            )
    
    # Check if pick already exists
    existing_pick_result = await db.execute(
        select(Pick).where(
            (Pick.player_id == current_user.id) & 
            (Pick.game_id == pick_data.game_id)
        )
    )
    existing_pick = existing_pick_result.scalar_one_or_none()
    
    if existing_pick:
        # Update existing pick
        existing_pick.pick_id = pick_data.team_id
        await db.commit()
        await db.refresh(existing_pick)
        return existing_pick
    else:
        # Create new pick
        new_pick = Pick(
            player_id=current_user.id,
            game_id=pick_data.game_id,
            pick_id=pick_data.team_id
        )
        db.add(new_pick)
        await db.commit()
        await db.refresh(new_pick)
        return new_pick


@router.get("/leaderboard", response_model=List[LeaderboardEntry])
async def get_leaderboard(db: AsyncSession = Depends(get_db)):
    """Get the current leaderboard."""
    tournament_service = TournamentService(db)
    leaderboard = await tournament_service.get_leaderboard()
    
    return [
        LeaderboardEntry(
            player={
                "id": entry["player"].id,
                "login": entry["player"].login,
                "first_name": entry["player"].first_name,
                "last_name": entry["player"].last_name,
                "full_name": entry["player"].full_name
            },
            score=entry["score"]
        )
        for entry in leaderboard
    ]


# Admin routes
@router.put("/admin/game/{game_id}/result")
async def update_game_result(
    game_id: int,
    result_data: UpdateGameResultRequest,
    db: AsyncSession = Depends(get_db),
    current_user: Player = Depends(get_current_admin_user)
):
    """Update the result of a game (admin only)."""
    tournament_service = TournamentService(db)
    
    try:
        await tournament_service.update_game_result(game_id, result_data.winner_id)
        return {"message": "Game result updated successfully"}
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )

