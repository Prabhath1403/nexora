from uuid import UUID
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, and_
from pydantic import BaseModel

from app.db.session import get_db
from app.db.models import Habit, HabitLog, ActivityPing

router = APIRouter(prefix="/habits", tags=["Habits"])

class HabitCreate(BaseModel):
    title: str
    description: str | None = None
    category: str = "General"
    frequency: str = "daily"
    target_count: int = 1
    target_type: str = "manual"        # manual, work_hours, learning_hours
    target_value: float = 1.0          # e.g., 3.0 for 3 hours of work, 2.0 for 2 hours of learning
    color_hex: str = "#6366F1"
    icon_name: str = "check_circle"

class HabitLogCreate(BaseModel):
    count: int = 1
    notes: str | None = None

DEFAULT_HABITS = [
    {
        "title": "Work 3 Hours",
        "category": "Productivity",
        "target_type": "work_hours",
        "target_value": 3.0,
        "color_hex": "#6366F1",
        "icon_name": "work",
    },
    {
        "title": "Learn 2 Hours",
        "category": "Learning",
        "target_type": "learning_hours",
        "target_value": 2.0,
        "color_hex": "#EC4899",
        "icon_name": "school",
    },
    {
        "title": "Drink 2L Water",
        "category": "Health",
        "target_type": "manual",
        "target_value": 1.0,
        "color_hex": "#10B981",
        "icon_name": "local_drink",
    },
]


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


@router.get("/weekly-grid")
async def get_weekly_grid(db: AsyncSession = Depends(get_db)):
    """
    Returns a Google Sheets-style 7-day checklist grid (Mon-Sun).
    Automatically checks off work_hours and learning_hours habits
    based on laptop daemon telemetry!
    """
    now = datetime.utcnow()
    today_date = now.date()

    # Calculate Monday of current week
    start_of_week = today_date - timedelta(days=today_date.weekday())
    week_dates = [start_of_week + timedelta(days=i) for i in range(7)]

    # Fetch active habits
    result = await db.execute(select(Habit).where(Habit.is_archived == False).order_by(Habit.created_at.asc()))
    habits = result.scalars().all()

    # Create default habits if none exist
    if not habits:
        for dh in DEFAULT_HABITS:
            h = Habit(**dh)
            db.add(h)
        await db.commit()
        result = await db.execute(select(Habit).where(Habit.is_archived == False).order_by(Habit.created_at.asc()))
        habits = result.scalars().all()

    # Query telemetry data for each day of the week
    week_telemetry = {}
    for d in week_dates:
        d_start = datetime(d.year, d.month, d.day, 0, 0, 0)
        d_end = d_start + timedelta(days=1)

        # Work seconds
        work_res = await db.execute(
            select(func.coalesce(func.sum(ActivityPing.duration_seconds), 0))
            .where(ActivityPing.category == "work")
            .where(and_(ActivityPing.timestamp >= d_start, ActivityPing.timestamp < d_end))
        )
        work_secs = work_res.scalar() or 0

        # Learning seconds
        learn_res = await db.execute(
            select(func.coalesce(func.sum(ActivityPing.duration_seconds), 0))
            .where(ActivityPing.category == "learning")
            .where(and_(ActivityPing.timestamp >= d_start, ActivityPing.timestamp < d_end))
        )
        learn_secs = learn_res.scalar() or 0

        week_telemetry[d] = {
            "work_hours": round(work_secs / 3600, 2),
            "learning_hours": round(learn_secs / 3600, 2),
        }

    # Fetch existing habit logs for the week
    week_start_dt = datetime(start_of_week.year, start_of_week.month, start_of_week.day, 0, 0, 0)
    logs_res = await db.execute(
        select(HabitLog).where(HabitLog.completed_at >= week_start_dt)
    )
    logs = logs_res.scalars().all()

    # Map existing logs by (habit_id, date)
    log_map = {}
    for log in logs:
        l_date = (log.log_date or log.completed_at).date()
        log_map[(log.habit_id, l_date)] = log

    # Build weekly grid payload
    day_headers = []
    day_names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    for i, d in enumerate(week_dates):
        day_headers.append({
            "date": d.isoformat(),
            "day_name": day_names[i],
            "day_number": d.day,
            "is_today": d == today_date,
        })

    grid_habits = []
    for habit in habits:
        weekly_cells = []
        for d in week_dates:
            key = (habit.id, d)
            log = log_map.get(key)
            is_completed = log is not None
            auto_checked = log.auto_checked if log else False
            progress = 0.0

            # Evaluate auto-tracking criteria for work/learning habits
            if habit.target_type == "work_hours":
                progress = week_telemetry[d]["work_hours"]
                if progress >= habit.target_value:
                    is_completed = True
                    auto_checked = True
            elif habit.target_type == "learning_hours":
                progress = week_telemetry[d]["learning_hours"]
                if progress >= habit.target_value:
                    is_completed = True
                    auto_checked = True

            weekly_cells.append({
                "date": d.isoformat(),
                "completed": is_completed,
                "auto_checked": auto_checked,
                "progress": progress,
                "target_value": habit.target_value,
                "is_today": d == today_date,
            })

        grid_habits.append({
            "id": str(habit.id),
            "title": habit.title,
            "category": habit.category,
            "target_type": habit.target_type,
            "target_value": habit.target_value,
            "color_hex": habit.color_hex,
            "icon_name": habit.icon_name,
            "weekly_cells": weekly_cells,
        })

    # Calculate daily completion ratios for past 7 days (trend)
    weekly_trend = []
    for day_idx in range(7):
        completed_on_day = sum(
            1 for gh in grid_habits if gh["weekly_cells"][day_idx]["completed"]
        )
        total_habits = len(grid_habits) if grid_habits else 1
        weekly_trend.append(round(completed_on_day / total_habits, 2))

    # Calculate streak (consecutive days with at least 1 completed habit up to today)
    streak_count = 0
    today_idx = next((i for i, h in enumerate(day_headers) if h["is_today"]), 6)
    for day_idx in range(today_idx, -1, -1):
        any_completed = any(gh["weekly_cells"][day_idx]["completed"] for gh in grid_habits)
        if any_completed:
            streak_count += 1
        else:
            break

    return {
        "headers": day_headers,
        "habits": grid_habits,
        "weekly_trend": weekly_trend,
        "streak_count": max(streak_count, 1 if any(gh["weekly_cells"][today_idx]["completed"] for gh in grid_habits) else 0),
    }


@router.post("/{habit_id}/toggle-date")
async def toggle_habit_date(habit_id: UUID, date_str: str, db: AsyncSession = Depends(get_db)):
    """Toggle habit completion status for a specific date (YYYY-MM-DD)."""
    result = await db.execute(select(Habit).where(Habit.id == habit_id))
    habit = result.scalar_one_or_none()
    if not habit:
        raise HTTPException(status_code=404, detail="Habit not found")

    try:
        target_date = datetime.strptime(date_str, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")

    target_dt = datetime(target_date.year, target_date.month, target_date.day, 12, 0, 0)
    d_start = datetime(target_date.year, target_date.month, target_date.day, 0, 0, 0)
    d_end = d_start + timedelta(days=1)

    # Check if a log already exists for this habit on this date
    existing_res = await db.execute(
        select(HabitLog)
        .where(HabitLog.habit_id == habit_id)
        .where(and_(HabitLog.completed_at >= d_start, HabitLog.completed_at < d_end))
    )
    existing_log = existing_res.scalar_one_or_none()

    if existing_log:
        await db.delete(existing_log)
        status = "uncompleted"
    else:
        new_log = HabitLog(
            habit_id=habit_id,
            completed_at=target_dt,
            log_date=target_dt,
            count=1,
            auto_checked=False,
        )
        db.add(new_log)
        status = "completed"

    await db.commit()
    return {"status": status, "date": date_str, "habit_id": str(habit_id)}


@router.delete("/{habit_id}")
async def delete_habit(habit_id: UUID, db: AsyncSession = Depends(get_db)):
    """Soft delete / archive a habit."""
    result = await db.execute(select(Habit).where(Habit.id == habit_id))
    habit = result.scalar_one_or_none()
    if not habit:
        raise HTTPException(status_code=404, detail="Habit not found")

    habit.is_archived = True
    await db.commit()
    return {"status": "archived", "habit_id": str(habit_id)}

