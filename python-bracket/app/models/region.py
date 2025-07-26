from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from typing import List, TYPE_CHECKING

from .base import Base

if TYPE_CHECKING:
    from .team import Team
    from .game import Game


class Region(Base):
    __tablename__ = "regions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)

    # Relationships
    teams: Mapped[List["Team"]] = relationship("Team", back_populates="region")
    games: Mapped[List["Game"]] = relationship("Game", back_populates="region")

    def __repr__(self) -> str:
        return f"<Region(id={self.id}, name='{self.name}')>"

