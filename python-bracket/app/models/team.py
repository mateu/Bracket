from sqlalchemy import Integer, String, SmallInteger, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from typing import List, Optional, TYPE_CHECKING

from .base import Base

if TYPE_CHECKING:
    from .region import Region
    from .pick import Pick


class Team(Base):
    __tablename__ = "teams"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    seed: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    name: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    region_id: Mapped[int] = mapped_column(Integer, ForeignKey("regions.id"), nullable=False)
    url: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    # Relationships
    region: Mapped["Region"] = relationship("Region", back_populates="teams")
    picks: Mapped[List["Pick"]] = relationship("Pick", back_populates="pick_team")

    def __repr__(self) -> str:
        return f"<Team(id={self.id}, name='{self.name}', seed={self.seed})>"

