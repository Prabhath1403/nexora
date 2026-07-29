from uuid import UUID
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from pydantic import BaseModel

from app.db.session import get_db
from app.db.models import Habit, HabitLog

router = APIRouter(prefix="/habits", tags=["Habits"])

class HabitCreate(BaseModel):
    title: str
    description: str | None = None
    category: str = "General"
    frequency: str = "daily"
    target_count: int = 1
    color_hex: str = "#6366F1"
    icon_name: str = "check_circle"

class HabitLogCreate(BaseModel):
    count: int = 1
    notes: str | None = None

@router.get("/")
async def list_habits(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Habit).where(Habit.is_archived == False))
    habits = result.scalars().all()
    return habits

@router.post("/")
async def create_habit(habit_data: HabitCreate, db: AsyncSession = Depends(get_db)):
    habit = Habit(**habit_data.model_dump())
    db.add(habit)
    await db.commit()
    await db.refresh(habit)
    return habit

@router.post("/{habit_id}/log")
async def log_habit(habit_id: UUID, log_data: HabitLogCreate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Habit).where(Habit.id == habit_id))
    habit = result.scalar_one_or_none()
    if not habit:
        raise HTTPException(status_code=404, detail="Habit not found")

    log = HabitLog(habit_id=habit_id, count=log_data.count, notes=log_data.notes)
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return log
