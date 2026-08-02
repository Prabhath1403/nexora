# 💡 Nucleus — Ideas, Project Milestones & Learning Roadmap

This document captures the overall vision, project tracking concepts, and learning path architecture for **Nucleus** — a personalized developer productivity ecosystem powered by zero-manual telemetry tracking.

---

## 🌟 1. Core Vision & Features Overview

Nucleus bridges the gap between **laptop telemetry**, **active project development**, **learning paths**, and **external productivity tools** (Google Calendar & GitHub).

```
 ┌─────────────────────────────────────────────────────────┐
 │               💻 Laptop Telemetry Daemon                 │
 │   (Tracks VS Code, Terminal, Brave Browsing & Idle)     │
 └────────────────────────────┬────────────────────────────┘
                              │
             ┌────────────────┴────────────────┐
             ▼                                 ▼
   📁 Active Projects Tracker       📚 Learning Roadmap & To-Dos
   - Project Milestones             - Tech Skills (Flutter, FastAPI)
   - Auto Work Hours Logging        - Course/Doc Links & Progress
   - GitHub Issue Sync              - Auto Learning Hours Logging
```

---

## 🚀 2. Active Projects & Task Milestones

Organize all active software projects with structured subtasks, priorities, and automated telemetry logging.

### 📌 Current Project Portfolio
1. **Nucleus Ecosystem (`nucleus`)**:
   - Flutter Mobile Frontend (Dark Mode, Glassmorphism, Google Sheets Habit Grid).
   - FastAPI Async Backend & PostgreSQL Database.
   - Laptop Activity Telemetry Daemon (`systemd` daemon + window tracker).
   - Google Calendar & Gmail OAuth Integrations.
   - GitHub Activity Telemetry Integration.

2. **AI Finance App (`Ai_finance`)**:
   - Financial analytics & expense classification powered by AI/LLMs.
   - Transaction logging, budget goals, and predictive insights.

3. **Developer Portfolio & Web Applications**:
   - Modern developer portfolio website showcasing full-stack projects.

---

## 📚 3. Learning Paths & Skill Roadmap

Track educational content (articles, courses, documentation, books) with percentage progress and automated reading time tracking.

### 🎯 Skill Roadmaps
* **Flutter & Cross-Platform Mobile Architecture**:
  * Advanced State Management & GoRouter Navigation.
  * Custom Animations, Glassmorphism, and Canvas Rendering.
  * Native Platform Channels (Android / Linux).

* **FastAPI, Async Python & Distributed Backend**:
  * AsyncSQLAlchemy, PostgreSQL indexing & query optimization.
  * Celery / Redis Background Worker Task Queues.
  * JWT Auth & OAuth 2.0 Security Protocols.

* **AI, LLM Integrations & Agentic Workflows**:
  * Function Calling, Structured Output JSON Schemas.
  * Vector Databases (ChromaDB / Qdrant) & RAG Pipelines.

* **DevOps, Docker & Cloud Infrastructure**:
  * Multi-stage Docker builds & Compose orchestration.
  * CI/CD pipelines with GitHub Actions.

---

## ⚡ 4. Telemetry-Powered Auto Tracking (Zero-Manual)

Instead of requiring manual timer start/stop:
* **Project Telemetry**: When VS Code or Terminal is focused on `/home/prabhath/projects/nucleus` or `/home/prabhath/projects/Ai_finance`, Nucleus automatically logs work time toward that project.
* **Learning Telemetry**: When Brave/Chrome is browsing documentation (`flutter.dev`, `fastapi.tiangolo.com`, `docs.python.org`) or developer tutorials, Nucleus automatically logs learning time toward the active Learning Path.

---

## 📅 5. Third-Party Integrations

* **Google Calendar**:
  * Pushes project task due dates and scheduled learning sessions to Google Calendar.
  * Pulls daily schedule into Nucleus dashboard.
* **Google Gmail**:
  * Quick view of important unread email summaries.
* **GitHub Integration**:
  * Auto-fetches open repository issues into Nucleus To-Dos.
  * Tracks commit activity & pull requests on active repositories.

---

## 🎯 6. Planned UI Features (Next Release)

1. **Dual-Tab Workspace (`ProjectsScreen`)**:
   - **Tab 1 — Projects**: Expandable card view per project with progress bars, due dates, and subtask checklists.
   - **Tab 2 — Learning Roadmap**: Categorized resource cards (Articles, Video Courses, Documentation) with progress sliders (`0%` to `100%`).
2. **Habit Tracker Sheet**:
   - 7-day Google Sheets checklist grid view with `⚡ AUTO` telemetry check-in.
