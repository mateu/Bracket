from sqlalchemy import Integer, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from typing import TYPE_CHECKING

from .base import Base, TimestampMixin

if TYPE_CHECKING:
    from .player import Player
    from .game import Game
    from .team import Team


class Pick(Base, TimestampMixin):
    __tablename__ = "picks"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    player_id: Mapped[int] = mapped_column(Integer, ForeignKey("players.id"), nullable=False)
    game_id: Mapped[int] = mapped_column(Integer, ForeignKey("games.id"), nullable=False)
    pick_id: Mapped[int] = mapped_column(Integer, ForeignKey("teams.id"), nullable=False)

    # Relationships
    player: Mapped["Player"] = relationship("Player", back_populates="picks")
    game: Mapped["Game"] = relationship("Game", back_populates="picks")
    pick_team: Mapped["Team"] = relationship("Team", back_populates="picks")

    @property
    def is_correct(self) -> bool:
        """Check if this pick is correct based on the game result."""
        return self.game.winner_id == self.pick_id if self.game.winner_id else False

    def __repr__(self) -> str:
        return f"<Pick(id={self.id}, player_id={self.player_id}, game_id={self.game_id}, pick_id={self.pick_id})>"

