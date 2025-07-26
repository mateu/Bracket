from sqlalchemy import create_engine
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker
from typing import AsyncGenerator

from .config import settings
from ..models.base import Base

# Create async engine
if settings.database_url.startswith("sqlite"):
    # For SQLite, use aiosqlite
    async_database_url = settings.database_url.replace("sqlite://", "sqlite+aiosqlite://")
else:
    # For PostgreSQL, use asyncpg
    async_database_url = settings.database_url.replace("postgresql://", "postgresql+asyncpg://")

async_engine = create_async_engine(
    async_database_url,
    echo=settings.debug,
    future=True
)

# Create async session factory
AsyncSessionLocal = sessionmaker(
    bind=async_engine,
    class_=AsyncSession,
    expire_on_commit=False
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Dependency to get database session."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()


async def create_tables():
    """Create all tables."""
    async with async_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def seed_initial_data():
    """Seed initial data into the database."""
    from ..models import Region, Tournament
    
    async with AsyncSessionLocal() as session:
        # Check if regions already exist
        result = await session.execute("SELECT COUNT(*) FROM regions")
        region_count = result.scalar()
        
        if region_count > 0:
            return
        
        # Create regions
        regions = [
            Region(id=1, name="East"),
            Region(id=2, name="Midwest"),
            Region(id=3, name="South"),
            Region(id=4, name="West"),
        ]
        
        for region in regions:
            session.add(region)
        
        # Create sample tournament
        tournament = Tournament(
            year=2024,
            name="NCAA Men's Basketball Tournament 2024",
            is_active=True,
            picks_locked=False
        )
        session.add(tournament)
        
        await session.commit()
        print("Initial data seeded successfully")

