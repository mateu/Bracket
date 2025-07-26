from datetime import datetime
from sqlalchemy import Integer, String, Boolean, DateTime
from sqlalchemy.orm import Mapped, mapped_column
from typing import Optional

from .base import Base, TimestampMixin


class Tournament(Base, TimestampMixin):
    __tablename__ = "tournaments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    year: Mapped[int] = mapped_column(Integer, unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    start_date: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    end_date: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    picks_locked: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    @property
    def is_current(self) -> bool:
        """Check if this tournament is currently active."""
        return self.is_active

    @property
    def can_make_picks(self) -> bool:
        """Check if picks can still be made for this tournament."""
        return self.is_active and not self.picks_locked

    def __repr__(self) -> str:
        return f"<Tournament(id={self.id}, year={self.year}, name='{self.name}', active={self.is_active})>"

