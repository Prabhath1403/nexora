from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from pydantic import BaseModel
from datetime import datetime

from app.db.session import get_db
from app.db.models import LearningResource

router = APIRouter(prefix="/learning", tags=["Learning Tracker"])

class LearningResourceCreate(BaseModel):
    title: str
    resource_type: str = "course"  # course, article, documentation, book
    url: str | None = None
    status: str = "to_read"       # to_read, in_progress, completed
    progress_percentage: float = 0.0
    notes: str | None = None
    tags: list[str] | None = None

class LearningResourceUpdate(BaseModel):
    status: str | None = None
    progress_percentage: float | None = None
    notes: str | None = None

DEFAULT_LEARNING_RESOURCES = [
    {
        "title": "Flutter Advanced UI & State Management",
        "resource_type": "course",
        "url": "https://flutter.dev/docs",
        "status": "in_progress",
        "progress_percentage": 65.0,
        "notes": "Covering Riverpod, Custom Animations & Glassmorphism design.",
        "tags": ["Flutter", "Dart", "Frontend"]
    },
    {
        "title": "FastAPI & Async PostgreSQL Optimization",
        "resource_type": "documentation",
        "url": "https://fastapi.tiangolo.com",
        "status": "in_progress",
        "progress_percentage": 80.0,
        "notes": "AsyncSQLAlchemy 2.0, Alembic migrations & Connection Pooling.",
        "tags": ["FastAPI", "Python", "PostgreSQL"]
    },
    {
        "title": "AI & Agentic Workflows with Function Calling",
        "resource_type": "article",
        "url": "https://ai.google.dev",
        "status": "to_read",
        "progress_percentage": 25.0,
        "notes": "Structured JSON outputs, tool declarations & multi-agent systems.",
        "tags": ["AI", "Gemini", "LLM"]
    },
    {
        "title": "Docker & Multi-Stage Production Builds",
        "resource_type": "documentation",
        "url": "https://docs.docker.com",
        "status": "completed",
        "progress_percentage": 100.0,
        "notes": "Alpine base images, layer caching, docker compose orchestration.",
        "tags": ["Docker", "DevOps"]
    }
]

@router.get("/")
async def list_learning_resources(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(LearningResource).order_by(LearningResource.created_at.desc()))
    resources = result.scalars().all()
    if not resources:
        for item in DEFAULT_LEARNING_RESOURCES:
            res = LearningResource(**item)
            db.add(res)
        await db.commit()
        result = await db.execute(select(LearningResource).order_by(LearningResource.created_at.desc()))
        resources = result.scalars().all()
    return resources

@router.post("/")
async def create_learning_resource(data: LearningResourceCreate, db: AsyncSession = Depends(get_db)):
    res = LearningResource(**data.model_dump())
    db.add(res)
    await db.commit()
    await db.refresh(res)
    return res

@router.patch("/{resource_id}")
async def update_learning_resource(resource_id: UUID, data: LearningResourceUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(LearningResource).where(LearningResource.id == resource_id))
    res = result.scalar_one_or_none()
    if not res:
        raise HTTPException(status_code=404, detail="Resource not found")
    
    update_data = data.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(res, key, value)
    
    if res.progress_percentage >= 100.0:
        res.status = "completed"
    elif res.progress_percentage > 0.0:
        res.status = "in_progress"

    await db.commit()
    await db.refresh(res)
    return res

@router.delete("/{resource_id}")
async def delete_learning_resource(resource_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(LearningResource).where(LearningResource.id == resource_id))
    res = result.scalar_one_or_none()
    if not res:
        raise HTTPException(status_code=404, detail="Resource not found")
    await db.delete(res)
    await db.commit()
    return {"status": "ok", "message": "Learning resource deleted"}

