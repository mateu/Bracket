from datetime import datetime
from sqlalchemy import Integer, String, ForeignKey, DateTime, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from typing import Optional, TYPE_CHECKING

from .base import Base

if TYPE_CHECKING:
    from .player import Player


class Session(Base):
    __tablename__ = "sessions"

    id: Mapped[str] = mapped_column(String(255), primary_key=True)
    player_id: Mapped[int] = mapped_column(Integer, ForeignKey("players.id"), nullable=False)
    data: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    # Relationships
    player: Mapped["Player"] = relationship("Player", back_populates="sessions")

    @property
    def is_expired(self) -> bool:
        return datetime.utcnow() > self.expires_at

    def __repr__(self) -> str:
        return f"<Session(id='{self.id}', player_id={self.player_id}, expires_at={self.expires_at})>"

