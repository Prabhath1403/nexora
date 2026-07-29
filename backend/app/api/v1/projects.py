from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from pydantic import BaseModel

from app.db.session import get_db
from app.db.models import Project, Task

router = APIRouter(prefix="/projects", tags=["Projects & Tasks"])

class ProjectCreate(BaseModel):
    name: str
    description: str | None = None
    github_repo: str | None = None
    color_hex: str = "#3B82F6"

class TaskCreate(BaseModel):
    project_id: UUID | None = None
    title: str
    description: str | None = None
    priority: str = "medium"

@router.get("/")
async def list_projects(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Project).options(selectinload(Project.tasks)))
    return result.scalars().all()

@router.post("/")
async def create_project(data: ProjectCreate, db: AsyncSession = Depends(get_db)):
    project = Project(**data.model_dump())
    db.add(project)
    await db.commit()
    await db.refresh(project)
    return project

@router.get("/tasks")
async def list_tasks(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Task))
    return result.scalars().all()

@router.post("/tasks")
async def create_task(data: TaskCreate, db: AsyncSession = Depends(get_db)):
    task = Task(**data.model_dump())
    db.add(task)
    await db.commit()
    await db.refresh(task)
    return task
