import uuid
from datetime import datetime
from sqlalchemy import String, Boolean, DateTime, Integer, Text, ForeignKey, Float, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID
from app.db.base import Base

class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    username: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    hashed_password: Mapped[str] = mapped_column(String(255))
    email: Mapped[str] = mapped_column(String(255), unique=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class Habit(Base):
    __tablename__ = "habits"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title: Mapped[str] = mapped_column(String(255))
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    category: Mapped[str] = mapped_column(String(50), default="General")  # Health, Productivity, Mindset
    frequency: Mapped[str] = mapped_column(String(50), default="daily")  # daily, weekly, custom
    target_count: Mapped[int] = mapped_column(Integer, default=1)
    target_type: Mapped[str] = mapped_column(String(50), default="manual")  # manual, work_hours, learning_hours
    target_value: Mapped[float] = mapped_column(Float, default=1.0)         # e.g., 3.0 for 3h work, 2.0 for 2h learn
    color_hex: Mapped[str] = mapped_column(String(10), default="#6366F1")
    icon_name: Mapped[str] = mapped_column(String(50), default="check_circle")
    is_archived: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    logs: Mapped[list["HabitLog"]] = relationship("HabitLog", back_populates="habit", cascade="all, delete-orphan")

class HabitLog(Base):
    __tablename__ = "habit_logs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    habit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("habits.id"))
    completed_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    log_date: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)  # Date for the daily grid check
    count: Mapped[int] = mapped_column(Integer, default=1)
    auto_checked: Mapped[bool] = mapped_column(Boolean, default=False)          # Automatically checked by daemon
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    habit: Mapped["Habit"] = relationship("Habit", back_populates="logs")

class Project(Base):
    __tablename__ = "projects"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(255))
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    github_repo: Mapped[str | None] = mapped_column(String(255), nullable=True)
    status: Mapped[str] = mapped_column(String(50), default="active")  # active, completed, paused
    color_hex: Mapped[str] = mapped_column(String(10), default="#3B82F6")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    tasks: Mapped[list["Task"]] = relationship("Task", back_populates="project", cascade="all, delete-orphan")
    work_logs: Mapped[list["WorkHourLog"]] = relationship("WorkHourLog", back_populates="project", cascade="all, delete-orphan")

class Task(Base):
    __tablename__ = "tasks"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("projects.id"), nullable=True)
    title: Mapped[str] = mapped_column(String(255))
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(50), default="todo")  # todo, in_progress, done
    priority: Mapped[str] = mapped_column(String(50), default="medium")  # low, medium, high, urgent
    due_date: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    google_calendar_event_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    gmail_message_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    github_issue_number: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    project: Mapped["Project | None"] = relationship("Project", back_populates="tasks")

class WorkHourLog(Base):
    __tablename__ = "work_hour_logs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("projects.id"), nullable=True)
    task_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("tasks.id"), nullable=True)
    start_time: Mapped[datetime] = mapped_column(DateTime)
    end_time: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    duration_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    project: Mapped["Project | None"] = relationship("Project", back_populates="work_logs")

class LearningResource(Base):
    __tablename__ = "learning_resources"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title: Mapped[str] = mapped_column(String(255))
    resource_type: Mapped[str] = mapped_column(String(50), default="article")  # book, article, video, course
    url: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(50), default="to_read")  # to_read, in_progress, completed
    progress_percentage: Mapped[float] = mapped_column(Float, default=0.0)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    tags: Mapped[list[str] | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class FocusSession(Base):
    __tablename__ = "focus_sessions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    duration_minutes: Mapped[int] = mapped_column(Integer, default=25)
    session_type: Mapped[str] = mapped_column(String(50), default="pomodoro")  # pomodoro, short_break, long_break
    completed: Mapped[bool] = mapped_column(Boolean, default=True)
    associated_task_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("tasks.id"), nullable=True)
    completed_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

class IntegrationToken(Base):
    __tablename__ = "integration_tokens"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    service_name: Mapped[str] = mapped_column(String(50), unique=True)  # google, github
    access_token: Mapped[str] = mapped_column(Text)
    refresh_token: Mapped[str | None] = mapped_column(Text, nullable=True)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    metadata_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class ActivityPing(Base):
    __tablename__ = "activity_pings"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    window_title: Mapped[str] = mapped_column(String(500))
    app_name: Mapped[str] = mapped_column(String(255), default="unknown")
    app_class: Mapped[str] = mapped_column(String(255), default="")             # WM_CLASS from window manager
    category: Mapped[str] = mapped_column(String(50), default="idle")           # work, learning, browsing, idle, afk
    duration_seconds: Mapped[int] = mapped_column(Integer, default=30)
    project_hint: Mapped[str] = mapped_column(String(255), default="")          # Extracted project folder name
    idle_ms: Mapped[int] = mapped_column(Integer, default=0)                    # Milliseconds of user idle time
    timestamp: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

