"""
Auto Tracker Endpoints — Receives heartbeats from the laptop daemon
and provides aggregated work/learning hours summaries for the Dashboard.
"""

from datetime import datetime, timedelta
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func
from pydantic import BaseModel

from app.db.session import get_db
from app.db.models import ActivityPing

router = APIRouter(prefix="/tracker", tags=["Auto Tracker"])


class PingData(BaseModel):
    window_title: str
    app_name: str = "unknown"
    category: str = "idle"  # work, learning, idle
    duration_seconds: int = 30


@router.post("/ping")
async def receive_ping(data: PingData, db: AsyncSession = Depends(get_db)):
    """
    Receives a heartbeat from the laptop daemon.
    Each ping represents ~30 seconds of tracked activity.
    """
    ping = ActivityPing(
        window_title=data.window_title,
        app_name=data.app_name,
        category=data.category,
        duration_seconds=data.duration_seconds,
    )
    db.add(ping)
    await db.commit()
    return {"status": "ok", "category": data.category}


@router.get("/summary")
async def get_summary(db: AsyncSession = Depends(get_db)):
    """
    Returns today's aggregated work hours, learning hours, and recent pings
    for the Dashboard widgets.
    """
    today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)

    # Total work seconds today
    work_result = await db.execute(
        select(func.coalesce(func.sum(ActivityPing.duration_seconds), 0))
        .where(ActivityPing.category == "work")
        .where(ActivityPing.timestamp >= today_start)
    )
    work_seconds = work_result.scalar() or 0

    # Total learning seconds today
    learn_result = await db.execute(
        select(func.coalesce(func.sum(ActivityPing.duration_seconds), 0))
        .where(ActivityPing.category == "learning")
        .where(ActivityPing.timestamp >= today_start)
    )
    learn_seconds = learn_result.scalar() or 0

    # Last 5 pings (for recent activity preview)
    recent_result = await db.execute(
        select(ActivityPing)
        .order_by(ActivityPing.timestamp.desc())
        .limit(5)
    )
    recent_pings = recent_result.scalars().all()

    return {
        "work_hours_today": round(work_seconds / 3600, 1),
        "work_seconds_today": work_seconds,
        "learning_hours_today": round(learn_seconds / 3600, 1),
        "learning_seconds_today": learn_seconds,
        "total_hours_today": round((work_seconds + learn_seconds) / 3600, 1),
        "recent_activity": [
            {
                "window_title": p.window_title,
                "app_name": p.app_name,
                "category": p.category,
                "timestamp": p.timestamp.isoformat(),
            }
            for p in recent_pings
        ],
    }


@router.get("/status")
async def daemon_status(db: AsyncSession = Depends(get_db)):
    """
    Returns the daemon's last-seen timestamp so the UI can show
    whether the laptop tracker is Active or Offline.
    """
    result = await db.execute(
        select(ActivityPing)
        .order_by(ActivityPing.timestamp.desc())
        .limit(1)
    )
    last_ping = result.scalar_one_or_none()

    if last_ping:
        age = datetime.utcnow() - last_ping.timestamp
        is_active = age < timedelta(minutes=2)  # Active if pinged within last 2 min
        return {
            "active": is_active,
            "last_seen": last_ping.timestamp.isoformat(),
            "last_app": last_ping.app_name,
            "last_category": last_ping.category,
            "age_seconds": int(age.total_seconds()),
        }

    return {"active": False, "last_seen": None, "last_app": None}


@router.get("/weekly")
async def weekly_summary(db: AsyncSession = Depends(get_db)):
    """
    Returns daily work and learning hours for the past 7 days.
    Used by the Dashboard habit/work trend charts.
    """
    days = []
    for i in range(6, -1, -1):
        day = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0) - timedelta(days=i)
        next_day = day + timedelta(days=1)

        work_result = await db.execute(
            select(func.coalesce(func.sum(ActivityPing.duration_seconds), 0))
            .where(ActivityPing.category == "work")
            .where(ActivityPing.timestamp >= day)
            .where(ActivityPing.timestamp < next_day)
        )
        learn_result = await db.execute(
            select(func.coalesce(func.sum(ActivityPing.duration_seconds), 0))
            .where(ActivityPing.category == "learning")
            .where(ActivityPing.timestamp >= day)
            .where(ActivityPing.timestamp < next_day)
        )

        days.append({
            "date": day.strftime("%Y-%m-%d"),
            "day_name": day.strftime("%a"),
            "work_hours": round((work_result.scalar() or 0) / 3600, 1),
            "learning_hours": round((learn_result.scalar() or 0) / 3600, 1),
        })

    return {"days": days}
