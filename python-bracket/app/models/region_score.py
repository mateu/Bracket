from sqlalchemy import Integer, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from typing import TYPE_CHECKING

from .base import Base

if TYPE_CHECKING:
    from .player import Player
    from .region import Region


class RegionScore(Base):
    __tablename__ = "region_scores"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    player_id: Mapped[int] = mapped_column(Integer, ForeignKey("players.id"), nullable=False)
    region_id: Mapped[int] = mapped_column(Integer, ForeignKey("regions.id"), nullable=False)
    points: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    # Relationships
    player: Mapped["Player"] = relationship("Player", back_populates="region_scores")
    region: Mapped["Region"] = relationship("Region")

    def __repr__(self) -> str:
        return f"<RegionScore(id={self.id}, player_id={self.player_id}, region_id={self.region_id}, points={self.points})>"

