from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from pydantic import BaseModel

from app.db.session import get_db
from app.db.models import LearningResource

router = APIRouter(prefix="/learning", tags=["Learning Tracker"])

class LearningResourceCreate(BaseModel):
    title: str
    resource_type: str = "article"
    url: str | None = None
    tags: list[str] | None = None

@router.get("/")
async def list_learning_resources(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(LearningResource).order_by(LearningResource.created_at.desc()))
    return result.scalars().all()

@router.post("/")
async def create_learning_resource(data: LearningResourceCreate, db: AsyncSession = Depends(get_db)):
    res = LearningResource(**data.model_dump())
    db.add(res)
    await db.commit()
    await db.refresh(res)
    return res
