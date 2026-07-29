from uuid import UUID
from datetime import datetime
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from pydantic import BaseModel

from app.db.session import get_db
from app.db.models import FocusSession

router = APIRouter(prefix="/focus", tags=["Focus & Pomodoro"])

class FocusSessionCreate(BaseModel):
    duration_minutes: int = 25
    session_type: str = "pomodoro"
    associated_task_id: UUID | None = None

@router.get("/")
async def list_focus_sessions(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(FocusSession).order_by(FocusSession.completed_at.desc()))
    return result.scalars().all()

@router.post("/")
async def record_focus_session(data: FocusSessionCreate, db: AsyncSession = Depends(get_db)):
    session = FocusSession(**data.model_dump())
    db.add(session)
    await db.commit()
    await db.refresh(session)
    return session
