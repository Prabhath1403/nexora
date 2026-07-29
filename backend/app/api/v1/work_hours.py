from uuid import UUID
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from pydantic import BaseModel

from app.db.session import get_db
from app.db.models import WorkHourLog

router = APIRouter(prefix="/work-hours", tags=["Work Hours Tracker"])

class WorkHourStart(BaseModel):
    project_id: UUID | None = None
    task_id: UUID | None = None
    description: str | None = None

class WorkHourStop(BaseModel):
    log_id: UUID
    description: str | None = None

@router.get("/")
async def list_work_logs(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(WorkHourLog).order_by(WorkHourLog.start_time.desc()))
    return result.scalars().all()

@router.post("/start")
async def start_clock(data: WorkHourStart, db: AsyncSession = Depends(get_db)):
    log = WorkHourLog(
        project_id=data.project_id,
        task_id=data.task_id,
        start_time=datetime.utcnow(),
        description=data.description
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return log

@router.post("/stop")
async def stop_clock(data: WorkHourStop, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(WorkHourLog).where(WorkHourLog.id == data.log_id))
    log = result.scalar_one_or_none()
    if not log:
        raise HTTPException(status_code=404, detail="Work log entry not found")
    
    log.end_time = datetime.utcnow()
    duration = (log.end_time - log.start_time).total_seconds() / 60.0
    log.duration_minutes = int(duration)
    if data.description:
        log.description = data.description

    await db.commit()
    await db.refresh(log)
    return log
