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
    status: str = "active"

class TaskCreate(BaseModel):
    project_id: UUID | None = None
    title: str
    description: str | None = None
    priority: str = "medium"    # low, medium, high, urgent
    status: str = "todo"        # todo, in_progress, done

class TaskUpdate(BaseModel):
    status: str | None = None
    priority: str | None = None
    title: str | None = None

DEFAULT_PROJECTS = [
    {
        "name": "Nucleus Ecosystem",
        "description": "Developer productivity platform with telemetry daemon & mobile UI.",
        "github_repo": "Prabhath1403/nexora",
        "color_hex": "#6366F1",
        "status": "active",
    },
    {
        "name": "AI Finance App",
        "description": "Financial analytics and expense classification using LLMs.",
        "github_repo": "Prabhath1403/Ai_finance",
        "color_hex": "#10B981",
        "status": "active",
    },
    {
        "name": "Developer Portfolio",
        "description": "Personal developer portfolio website showcasing web & mobile apps.",
        "github_repo": "Prabhath1403/portfolio",
        "color_hex": "#F59E0B",
        "status": "completed",
    },
]

DEFAULT_TASKS = [
    {
        "title": "Implement Google Sheets Weekly Habit Grid",
        "priority": "high",
        "status": "done",
    },
    {
        "title": "Add Dual-Tab Workspace (Projects & Learning Roadmap)",
        "priority": "high",
        "status": "in_progress",
    },
    {
        "title": "Integrate Google Calendar OAuth Sync",
        "priority": "medium",
        "status": "todo",
    },
    {
        "title": "Configure GitHub Issue Auto-Import",
        "priority": "medium",
        "status": "todo",
    },
    {
        "title": "Build AI Expense Classifier Engine",
        "priority": "high",
        "status": "todo",
    },
]


@router.get("/")
async def list_projects(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Project).options(selectinload(Project.tasks)))
    projects = result.scalars().all()
    if not projects:
        for p_data in DEFAULT_PROJECTS:
            p = Project(**p_data)
            db.add(p)
        await db.commit()

        # Fetch projects to associate default tasks
        res = await db.execute(select(Project))
        created_projects = res.scalars().all()
        nucleus_p = next((p for p in created_projects if p.name == "Nucleus Ecosystem"), None)

        for t_data in DEFAULT_TASKS:
            t = Task(
                project_id=nucleus_p.id if nucleus_p else None,
                **t_data
            )
            db.add(t)
        await db.commit()

        result = await db.execute(select(Project).options(selectinload(Project.tasks)))
        projects = result.scalars().all()

    formatted = []
    for p in projects:
        total = len(p.tasks)
        completed = sum(1 for t in p.tasks if t.status == "done")
        progress = round(completed / total, 2) if total > 0 else 0.0
        formatted.append({
            "id": str(p.id),
            "name": p.name,
            "description": p.description,
            "github_repo": p.github_repo,
            "color_hex": p.color_hex,
            "status": p.status,
            "total_tasks": total,
            "completed_tasks": completed,
            "progress": progress,
            "created_at": p.created_at.isoformat() if p.created_at else None,
        })
    return formatted


@router.post("/")
async def create_project(data: ProjectCreate, db: AsyncSession = Depends(get_db)):
    project = Project(**data.model_dump())
    db.add(project)
    await db.commit()
    await db.refresh(project)
    return project


@router.delete("/{project_id}")
async def delete_project(project_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Project).where(Project.id == project_id))
    project = result.scalar_one_or_none()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    await db.delete(project)
    await db.commit()
    return {"status": "deleted", "project_id": str(project_id)}


@router.get("/tasks")
async def list_tasks(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Task).order_by(Task.created_at.desc()))
    tasks = result.scalars().all()
    if not tasks:
        for t_data in DEFAULT_TASKS:
            t = Task(**t_data)
            db.add(t)
        await db.commit()
        result = await db.execute(select(Task).order_by(Task.created_at.desc()))
        tasks = result.scalars().all()
    return tasks


@router.post("/tasks")
async def create_task(data: TaskCreate, db: AsyncSession = Depends(get_db)):
    task = Task(**data.model_dump())
    db.add(task)
    await db.commit()
    await db.refresh(task)
    return task


@router.patch("/tasks/{task_id}")
async def update_task(task_id: UUID, data: TaskUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Task).where(Task.id == task_id))
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    update_data = data.model_dump(exclude_unset=True)
    for key, val in update_data.items():
        setattr(task, key, val)

    await db.commit()
    await db.refresh(task)
    return task


@router.delete("/tasks/{task_id}")
async def delete_task(task_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Task).where(Task.id == task_id))
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    await db.delete(task)
    await db.commit()
    return {"status": "deleted", "task_id": str(task_id)}

