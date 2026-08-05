"""
Auto Tracker Endpoints — Receives heartbeats from the laptop daemon
and provides aggregated work/learning hours, app breakdowns, timeline,
and per-project time tracking for the Dashboard.
"""

from datetime import datetime, timedelta
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, case, distinct, delete
from pydantic import BaseModel

from app.db.session import get_db
from app.db.models import ActivityPing

router = APIRouter(prefix="/tracker", tags=["Auto Tracker"])


class PingData(BaseModel):
    window_title: str
    app_name: str = "unknown"
    app_class: str = ""              # WM_CLASS from window manager
    category: str = "idle"           # work, learning, browsing, idle, afk
    duration_seconds: int = 30
    project_hint: str = ""           # Extracted project folder name
    idle_ms: int = 0                 # Milliseconds of user idle time


@router.post("/ping")
async def receive_ping(data: PingData, db: AsyncSession = Depends(get_db)):
    """
    Receives a heartbeat from the laptop daemon.
    Each ping represents ~30 seconds of tracked activity.
    """
    ping = ActivityPing(
        window_title=data.window_title,
        app_name=data.app_name,
        app_class=data.app_class,
        category=data.category,
        duration_seconds=data.duration_seconds,
        project_hint=data.project_hint,
        idle_ms=data.idle_ms,
    )
    db.add(ping)
    await db.commit()
    return {"status": "ok", "category": data.category}


@router.post("/clear-logs")
@router.delete("/clear-logs")
async def clear_activity_logs(db: AsyncSession = Depends(get_db)):
    """
    Clears all old activity pings / telemetry cache from database
    so the integrations tab and app breakdown start completely fresh!
    """
    await db.execute(delete(ActivityPing))
    await db.commit()
    return {"status": "ok", "message": "All activity telemetry logs cleared."}


@router.get("/summary")
async def get_summary(db: AsyncSession = Depends(get_db)):
    """
    Returns today's aggregated work hours, learning hours, top app,
    active-since timestamp, and current session duration for the Dashboard.
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

    # Total browsing seconds today
    browse_result = await db.execute(
        select(func.coalesce(func.sum(ActivityPing.duration_seconds), 0))
        .where(ActivityPing.category == "browsing")
        .where(ActivityPing.timestamp >= today_start)
    )
    browse_seconds = browse_result.scalar() or 0

    # Top app today (most time spent)
    top_app_result = await db.execute(
        select(
            ActivityPing.app_name,
            func.sum(ActivityPing.duration_seconds).label("total_seconds"),
        )
        .where(ActivityPing.category.in_(["work", "learning"]))
        .where(ActivityPing.timestamp >= today_start)
        .group_by(ActivityPing.app_name)
        .order_by(func.sum(ActivityPing.duration_seconds).desc())
        .limit(1)
    )
    top_app_row = top_app_result.first()
    top_app = top_app_row[0] if top_app_row else None
    top_app_hours = round((top_app_row[1] or 0) / 3600, 1) if top_app_row else 0

    # First ping today (active since)
    first_ping_result = await db.execute(
        select(ActivityPing.timestamp)
        .where(ActivityPing.category.in_(["work", "learning"]))
        .where(ActivityPing.timestamp >= today_start)
        .order_by(ActivityPing.timestamp.asc())
        .limit(1)
    )
    first_ping = first_ping_result.scalar_one_or_none()
    active_since = first_ping.isoformat() if first_ping else None

    # Current session: time since last idle/afk gap (> 5 min)
    recent_pings_result = await db.execute(
        select(ActivityPing)
        .where(ActivityPing.timestamp >= today_start)
        .order_by(ActivityPing.timestamp.desc())
        .limit(100)
    )
    recent_pings = recent_pings_result.scalars().all()

    session_seconds = 0
    for ping in recent_pings:
        if ping.category in ("idle", "afk"):
            break
        session_seconds += ping.duration_seconds

    # Last 5 pings (for recent activity preview)
    last_five = recent_pings[:5]

    total_work_seconds = work_seconds + browse_seconds
    return {
        "work_hours_today": round(total_work_seconds / 3600, 2),
        "work_seconds_today": total_work_seconds,
        "learning_hours_today": round(learn_seconds / 3600, 2),
        "learning_seconds_today": learn_seconds,
        "browsing_hours_today": round(browse_seconds / 3600, 2),
        "browsing_seconds_today": browse_seconds,
        "total_hours_today": round((total_work_seconds + learn_seconds) / 3600, 2),
        "top_app": top_app,
        "top_app_hours": top_app_hours,
        "active_since": active_since,
        "current_session_minutes": round(session_seconds / 60, 0),
        "recent_activity": [
            {
                "window_title": p.window_title,
                "app_name": p.app_name,
                "category": p.category,
                "project_hint": p.project_hint,
                "timestamp": p.timestamp.isoformat(),
            }
            for p in last_five
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
            "last_project": last_ping.project_hint,
            "age_seconds": int(age.total_seconds()),
        }

    return {"active": False, "last_seen": None, "last_app": None, "last_project": None}


@router.get("/app-breakdown")
async def app_breakdown(db: AsyncSession = Depends(get_db)):
    """
    Returns today's time grouped by app name.
    Example: [{"app": "VSCode", "hours": 4.2, "seconds": 15120, "category": "work"}, ...]
    """
    today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)

    result = await db.execute(
        select(
            ActivityPing.app_name,
            ActivityPing.category,
            func.sum(ActivityPing.duration_seconds).label("total_seconds"),
            func.count(ActivityPing.id).label("ping_count"),
        )
        .where(ActivityPing.timestamp >= today_start)
        .where(ActivityPing.category.in_(["work", "learning", "browsing", "media"]))
        .group_by(ActivityPing.app_name, ActivityPing.category)
        .order_by(func.sum(ActivityPing.duration_seconds).desc())
    )
    rows = result.all()

    breakdown = []
    for row in rows:
        total_secs = row.total_seconds or 0
        breakdown.append({
            "app": row.app_name,
            "category": row.category,
            "hours": round(total_secs / 3600, 2),
            "seconds": total_secs,
            "ping_count": row.ping_count,
        })

    return {"breakdown": breakdown}


@router.get("/app-details")
async def get_app_details(app_name: str, db: AsyncSession = Depends(get_db)):
    """
    Returns detailed activities (web pages, projects, window titles) for a specific app today.
    Example query: /api/v1/tracker/app-details?app_name=Brave
    """
    today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)

    result = await db.execute(
        select(
            ActivityPing.window_title,
            ActivityPing.project_hint,
            ActivityPing.category,
            func.sum(ActivityPing.duration_seconds).label("total_seconds"),
            func.max(ActivityPing.timestamp).label("last_seen"),
        )
        .where(ActivityPing.timestamp >= today_start)
        .where(func.lower(ActivityPing.app_name) == app_name.lower())
        .group_by(ActivityPing.window_title, ActivityPing.project_hint, ActivityPing.category)
        .order_by(func.sum(ActivityPing.duration_seconds).desc())
        .limit(20)
    )
    rows = result.all()

    activities = []
    total_secs = 0
    for row in rows:
        secs = row.total_seconds or 0
        total_secs += secs
        activities.append({
            "title": row.window_title or f"{app_name} Activity",
            "project": row.project_hint or "",
            "category": row.category,
            "hours": round(secs / 3600, 2),
            "minutes": int(secs // 60),
            "last_seen": row.last_seen.isoformat() if row.last_seen else None,
        })

    return {
        "app_name": app_name,
        "total_hours": round(total_secs / 3600, 2),
        "activities": activities,
    }


@router.get("/timeline")
async def activity_timeline(db: AsyncSession = Depends(get_db)):
    """
    Returns today's activity timeline as sessions.
    Groups consecutive pings with the same app into sessions.
    """
    today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)

    result = await db.execute(
        select(ActivityPing)
        .where(ActivityPing.timestamp >= today_start)
        .where(ActivityPing.category.in_(["work", "learning", "browsing", "media"]))
        .order_by(ActivityPing.timestamp.asc())
    )
    pings = result.scalars().all()

    if not pings:
        return {"timeline": []}

    # Group consecutive same-app pings into sessions
    sessions = []
    current_session = {
        "app": pings[0].app_name,
        "category": pings[0].category,
        "project": pings[0].project_hint,
        "start": pings[0].timestamp,
        "end": pings[0].timestamp,
        "duration_seconds": pings[0].duration_seconds,
    }

    for ping in pings[1:]:
        # Same app → extend session
        if ping.app_name == current_session["app"]:
            current_session["end"] = ping.timestamp
            current_session["duration_seconds"] += ping.duration_seconds
            if ping.project_hint:
                current_session["project"] = ping.project_hint
        else:
            # Different app → close session, start new
            sessions.append(current_session)
            current_session = {
                "app": ping.app_name,
                "category": ping.category,
                "project": ping.project_hint,
                "start": ping.timestamp,
                "end": ping.timestamp,
                "duration_seconds": ping.duration_seconds,
            }

    # Don't forget the last session
    sessions.append(current_session)

    return {
        "timeline": [
            {
                "app": s["app"],
                "category": s["category"],
                "project": s["project"],
                "start": s["start"].isoformat(),
                "end": s["end"].isoformat(),
                "duration_minutes": round(s["duration_seconds"] / 60, 1),
            }
            for s in sessions
        ]
    }


@router.get("/projects")
async def project_time(db: AsyncSession = Depends(get_db)):
    """
    Returns time spent per project today.
    Example: [{"project": "nucleus", "hours": 3.1, "seconds": 11160}, ...]
    """
    today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)

    result = await db.execute(
        select(
            ActivityPing.project_hint,
            func.sum(ActivityPing.duration_seconds).label("total_seconds"),
        )
        .where(ActivityPing.timestamp >= today_start)
        .where(ActivityPing.project_hint != "")
        .where(ActivityPing.category.in_(["work", "learning"]))
        .group_by(ActivityPing.project_hint)
        .order_by(func.sum(ActivityPing.duration_seconds).desc())
    )
    rows = result.all()

    return {
        "projects": [
            {
                "project": row.project_hint,
                "hours": round((row.total_seconds or 0) / 3600, 2),
                "seconds": row.total_seconds or 0,
            }
            for row in rows
        ]
    }


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
