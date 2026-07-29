from fastapi import APIRouter
from app.api.v1 import habits, projects, work_hours, learning, focus, integrations, auto_tracker

api_router = APIRouter()
api_router.include_router(habits.router)
api_router.include_router(projects.router)
api_router.include_router(work_hours.router)
api_router.include_router(learning.router)
api_router.include_router(focus.router)
api_router.include_router(integrations.router)
api_router.include_router(auto_tracker.router)
