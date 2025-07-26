from sqlalchemy import Integer, SmallInteger, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from typing import List, Optional, TYPE_CHECKING

from .base import Base

if TYPE_CHECKING:
    from .region import Region
    from .team import Team
    from .pick import Pick


class Game(Base):
    __tablename__ = "games"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    round: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    region_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("regions.id"), nullable=True)
    team1_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("teams.id"), nullable=True)
    team2_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("teams.id"), nullable=True)
    winner_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("teams.id"), nullable=True)
    point_value: Mapped[int] = mapped_column(Integer, nullable=False)

    # Relationships
    region: Mapped[Optional["Region"]] = relationship("Region", back_populates="games")
    team1: Mapped[Optional["Team"]] = relationship("Team", foreign_keys=[team1_id])
    team2: Mapped[Optional["Team"]] = relationship("Team", foreign_keys=[team2_id])
    winner: Mapped[Optional["Team"]] = relationship("Team", foreign_keys=[winner_id])
    picks: Mapped[List["Pick"]] = relationship("Pick", back_populates="game")

    @property
    def is_completed(self) -> bool:
        return self.winner_id is not None

    @property
    def teams_set(self) -> bool:
        return self.team1_id is not None and self.team2_id is not None

    def __repr__(self) -> str:
        return f"<Game(id={self.id}, round={self.round}, completed={self.is_completed})>"

