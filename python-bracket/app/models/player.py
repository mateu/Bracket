from sqlalchemy import Integer, String, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from typing import List, TYPE_CHECKING

from .base import Base, TimestampMixin

if TYPE_CHECKING:
    from .pick import Pick
    from .region_score import RegionScore
    from .session import Session


class Player(Base, TimestampMixin):
    __tablename__ = "players"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    login: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    password: Mapped[str] = mapped_column(String(255), nullable=False)
    first_name: Mapped[str] = mapped_column(String(50), nullable=False)
    last_name: Mapped[str] = mapped_column(String(50), nullable=False)
    email: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    # Relationships
    picks: Mapped[List["Pick"]] = relationship("Pick", back_populates="player")
    region_scores: Mapped[List["RegionScore"]] = relationship("RegionScore", back_populates="player")
    sessions: Mapped[List["Session"]] = relationship("Session", back_populates="player")

    @property
    def full_name(self) -> str:
        return f"{self.first_name} {self.last_name}"

    def __repr__(self) -> str:
        return f"<Player(id={self.id}, login='{self.login}', name='{self.full_name}')>"

