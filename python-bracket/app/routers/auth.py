from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel, EmailStr
from typing import Optional

from ..core.database import get_db
from ..models.player import Player
from ..auth import verify_password, get_password_hash, create_access_token, get_current_user

router = APIRouter(prefix="/api/v1/auth", tags=["authentication"])


class UserRegister(BaseModel):
    login: str
    password: str
    first_name: str
    last_name: str
    email: EmailStr


class UserLogin(BaseModel):
    login: str
    password: str


class Token(BaseModel):
    access_token: str
    token_type: str


class UserResponse(BaseModel):
    id: int
    login: str
    first_name: str
    last_name: str
    email: str
    is_admin: bool
    active: bool

    class Config:
        from_attributes = True


@router.post("/register", response_model=UserResponse)
async def register(user_data: UserRegister, db: AsyncSession = Depends(get_db)):
    """Register a new user."""
    # Check if user already exists
    result = await db.execute(
        select(Player).where(
            (Player.login == user_data.login) | (Player.email == user_data.email)
        )
    )
    existing_user = result.scalar_one_or_none()
    
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User with this login or email already exists"
        )
    
    # Create new user
    hashed_password = get_password_hash(user_data.password)
    new_user = Player(
        login=user_data.login,
        password=hashed_password,
        first_name=user_data.first_name,
        last_name=user_data.last_name,
        email=user_data.email,
        is_admin=False,
        active=True
    )
    
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    
    return new_user


@router.post("/login", response_model=Token)
async def login(user_data: UserLogin, db: AsyncSession = Depends(get_db)):
    """Login user and return access token."""
    # Get user from database
    result = await db.execute(
        select(Player).where(Player.login == user_data.login)
    )
    user = result.scalar_one_or_none()
    
    if not user or not verify_password(user_data.password, user.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect login or password",
        )
    
    if not user.active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user",
        )
    
    # Create access token
    access_token = create_access_token(data={"sub": str(user.id)})
    
    return {
        "access_token": access_token,
        "token_type": "bearer"
    }


@router.get("/profile", response_model=UserResponse)
async def get_profile(current_user: Player = Depends(get_current_user)):
    """Get current user profile."""
    return current_user

