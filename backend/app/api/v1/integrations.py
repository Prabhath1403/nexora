"""
OAuth2 Integration Endpoints for GitHub and Google (Calendar + Gmail).

Flow:
1. Frontend calls GET /auth-url → gets the OAuth authorization URL
2. User visits that URL in browser, grants permission
3. Provider redirects to GET /callback with ?code=xxx
4. Backend exchanges code for tokens, stores in IntegrationToken table
5. Frontend polls GET /status to detect connection completion
"""

from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from pydantic import BaseModel
import httpx

from app.db.session import get_db
from app.db.models import IntegrationToken
from app.core.config import settings

router = APIRouter(prefix="/integrations", tags=["Integrations"])


# --- Pydantic Schemas ---

class IntegrationStatus(BaseModel):
    github: dict
    google: dict
    laptop_daemon: dict


# --- Status Endpoint ---

@router.get("/status")
async def get_integration_status(db: AsyncSession = Depends(get_db)):
    """Returns connection status for all integrations."""
    result = await db.execute(select(IntegrationToken))
    tokens = {t.service_name: t for t in result.scalars().all()}

    github_token = tokens.get("github")
    google_token = tokens.get("google")

    return {
        "github": {
            "connected": github_token is not None,
            "username": github_token.metadata_json.get("username") if github_token and github_token.metadata_json else None,
            "avatar_url": github_token.metadata_json.get("avatar_url") if github_token and github_token.metadata_json else None,
            "connected_at": github_token.updated_at.isoformat() if github_token else None,
        },
        "google": {
            "connected": google_token is not None,
            "email": google_token.metadata_json.get("email") if google_token and google_token.metadata_json else None,
            "scopes": google_token.metadata_json.get("scopes", []) if google_token and google_token.metadata_json else [],
            "connected_at": google_token.updated_at.isoformat() if google_token else None,
        },
        "laptop_daemon": {
            "connected": False,  # Will be updated by auto_tracker
            "last_seen": None,
        }
    }


# ==========================================
# GITHUB OAUTH2
# ==========================================

GITHUB_AUTH_URL = "https://github.com/login/oauth/authorize"
GITHUB_TOKEN_URL = "https://github.com/login/oauth/access_token"
GITHUB_USER_URL = "https://api.github.com/user"
GITHUB_SCOPES = "read:user repo"


@router.get("/github/auth-url")
async def github_auth_url():
    """Generate the GitHub OAuth authorization URL for the user to visit."""
    if not settings.GITHUB_CLIENT_ID:
        raise HTTPException(
            status_code=400,
            detail="GitHub OAuth is not configured. Set GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET in .env"
        )

    redirect_uri = f"{settings.BACKEND_URL}/api/v1/integrations/github/callback"
    url = (
        f"{GITHUB_AUTH_URL}"
        f"?client_id={settings.GITHUB_CLIENT_ID}"
        f"&redirect_uri={redirect_uri}"
        f"&scope={GITHUB_SCOPES}"
        f"&state=nucleus-github-auth"
    )
    return {"auth_url": url}


@router.get("/github/callback")
async def github_callback(code: str, state: str = "", db: AsyncSession = Depends(get_db)):
    """
    GitHub redirects here with ?code=xxx after user grants permission.
    Exchanges the code for an access token and stores it.
    """
    if not settings.GITHUB_CLIENT_ID or not settings.GITHUB_CLIENT_SECRET:
        raise HTTPException(status_code=400, detail="GitHub OAuth not configured")

    redirect_uri = f"{settings.BACKEND_URL}/api/v1/integrations/github/callback"

    # Exchange authorization code for access token
    async with httpx.AsyncClient() as client:
        token_response = await client.post(
            GITHUB_TOKEN_URL,
            data={
                "client_id": settings.GITHUB_CLIENT_ID,
                "client_secret": settings.GITHUB_CLIENT_SECRET,
                "code": code,
                "redirect_uri": redirect_uri,
            },
            headers={"Accept": "application/json"},
        )

        if token_response.status_code != 200:
            raise HTTPException(status_code=400, detail="Failed to exchange code for token")

        token_data = token_response.json()
        access_token = token_data.get("access_token")
        if not access_token:
            raise HTTPException(status_code=400, detail=f"GitHub error: {token_data.get('error_description', 'Unknown error')}")

        # Fetch user profile info
        user_response = await client.get(
            GITHUB_USER_URL,
            headers={"Authorization": f"Bearer {access_token}", "Accept": "application/json"},
        )
        user_data = user_response.json() if user_response.status_code == 200 else {}

    # Store or update token in database
    result = await db.execute(select(IntegrationToken).where(IntegrationToken.service_name == "github"))
    existing = result.scalar_one_or_none()

    metadata = {
        "username": user_data.get("login", "unknown"),
        "avatar_url": user_data.get("avatar_url", ""),
        "name": user_data.get("name", ""),
        "public_repos": user_data.get("public_repos", 0),
        "token_type": token_data.get("token_type", "bearer"),
        "scope": token_data.get("scope", ""),
    }

    if existing:
        existing.access_token = access_token
        existing.metadata_json = metadata
        existing.updated_at = datetime.utcnow()
    else:
        token_record = IntegrationToken(
            service_name="github",
            access_token=access_token,
            metadata_json=metadata,
        )
        db.add(token_record)

    await db.commit()

    # Return a simple HTML success page with deep-link redirect to return to mobile app
    username = user_data.get("login", "unknown")
    return HTMLResponse(content=f"""
    <html>
    <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body {{ background: #000; color: #fff; font-family: -apple-system, system-ui, sans-serif;
                   display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }}
            .card {{ text-align: center; padding: 40px; background: #1c1c1e; border-radius: 20px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); max-width: 320px; }}
            .check {{ font-size: 56px; margin-bottom: 12px; }}
            h2 {{ margin: 0 0 8px 0; font-size: 22px; font-weight: 700; }}
            p {{ color: #8e8e93; font-size: 14px; margin: 4px 0 24px 0; line-height: 1.4; }}
            .btn {{ display: inline-block; background: #007aff; color: #fff; font-weight: 600; text-decoration: none; padding: 14px 28px; border-radius: 12px; font-size: 15px; width: 80%; }}
        </style>
    </head>
    <body>
        <div class="card">
            <div class="check">✅</div>
            <h2>GitHub Connected!</h2>
            <p>Signed in as <strong>@{username}</strong></p>
            <a class="btn" href="nucleus://auth/callback">Open Nucleus App</a>
        </div>
        <script>
            setTimeout(function() {{
                window.location.href = "nucleus://auth/callback";
            }}, 800);
        </script>
    </body>
    </html>
    """)


@router.post("/github/disconnect")
async def github_disconnect(db: AsyncSession = Depends(get_db)):
    """Disconnect GitHub by removing the stored token."""
    result = await db.execute(select(IntegrationToken).where(IntegrationToken.service_name == "github"))
    token = result.scalar_one_or_none()
    if token:
        await db.delete(token)
        await db.commit()
    return {"status": "disconnected", "service": "github"}


@router.get("/github/activity")
async def github_activity(db: AsyncSession = Depends(get_db)):
    """Fetch recent GitHub activity (commits, repos) using stored token."""
    result = await db.execute(select(IntegrationToken).where(IntegrationToken.service_name == "github"))
    token = result.scalar_one_or_none()

    if not token:
        raise HTTPException(status_code=401, detail="GitHub not connected")

    async with httpx.AsyncClient() as client:
        headers = {"Authorization": f"Bearer {token.access_token}", "Accept": "application/json"}

        # Fetch recent events (commits, pushes, PRs)
        events_resp = await client.get(
            f"https://api.github.com/users/{token.metadata_json.get('username', '')}/events?per_page=10",
            headers=headers,
        )
        events = events_resp.json() if events_resp.status_code == 200 else []

        # Extract push events with commit details
        recent_commits = []
        for event in events:
            if event.get("type") == "PushEvent":
                repo_name = event.get("repo", {}).get("name", "unknown")
                payload = event.get("payload", {})
                branch = payload.get("ref", "refs/heads/main").split("/")[-1]
                for commit in payload.get("commits", [])[:3]:
                    recent_commits.append({
                        "repo": repo_name,
                        "message": commit.get("message", "").split("\n")[0],  # First line only
                        "sha": commit.get("sha", "")[:7],
                        "branch": branch,
                        "timestamp": event.get("created_at", ""),
                    })

        # Fetch active user repositories
        repos_resp = await client.get(
            "https://api.github.com/user/repos?sort=pushed&per_page=5",
            headers=headers,
        )
        active_repos = []
        if repos_resp.status_code == 200:
            for repo in repos_resp.json():
                active_repos.append({
                    "name": repo.get("full_name", ""),
                    "description": repo.get("description", ""),
                    "language": repo.get("language", ""),
                    "updated_at": repo.get("pushed_at", ""),
                    "stars": repo.get("stargazers_count", 0),
                    "open_issues": repo.get("open_issues_count", 0),
                })

        # Fetch contribution calendar grid via GitHub GraphQL API
        contribution_grid = []
        total_contributions = 0
        try:
            gql_resp = await client.post(
                "https://api.github.com/graphql",
                json={"query": "query { viewer { contributionsCollection { contributionCalendar { totalContributions weeks { contributionDays { contributionCount date } } } } } }"},
                headers={"Authorization": f"Bearer {token.access_token}"},
            )
            if gql_resp.status_code == 200:
                gql_data = gql_resp.json()
                calendar = gql_data.get("data", {}).get("viewer", {}).get("contributionsCollection", {}).get("contributionCalendar", {})
                total_contributions = calendar.get("totalContributions", 0)
                raw_weeks = calendar.get("weeks", [])
                
                # Take last 18 weeks for compact mobile grid view
                for week in raw_weeks[-18:]:
                    week_levels = []
                    for day in week.get("contributionDays", []):
                        cnt = day.get("contributionCount", 0)
                        # Map count to 0-4 intensity scale
                        level = 0 if cnt == 0 else (1 if cnt <= 2 else (2 if cnt <= 5 else (3 if cnt <= 8 else 4)))
                        week_levels.append(level)
                    while len(week_levels) < 7:
                        week_levels.append(0)
                    contribution_grid.append(week_levels)
        except Exception as e:
            print(f"Error fetching GitHub contribution calendar: {e}")

    return {
        "username": token.metadata_json.get("username", ""),
        "avatar_url": token.metadata_json.get("avatar_url", ""),
        "recent_commits": recent_commits[:10],
        "active_repos": active_repos,
        "total_commits_today": len([c for c in recent_commits if _is_today(c.get("timestamp", ""))]),
        "total_contributions": total_contributions,
        "contribution_grid": contribution_grid,
    }


@router.post("/github/import-issues")
async def import_github_issues(db: AsyncSession = Depends(get_db)):
    """Fetch open GitHub issues and import them as Nucleus Tasks."""
    result = await db.execute(select(IntegrationToken).where(IntegrationToken.service_name == "github"))
    token = result.scalar_one_or_none()
    if not token:
        raise HTTPException(status_code=401, detail="GitHub not connected")

    from app.db.models import Task, Project

    imported_count = 0
    async with httpx.AsyncClient() as client:
        headers = {"Authorization": f"Bearer {token.access_token}", "Accept": "application/json"}
        resp = await client.get("https://api.github.com/user/issues?filter=all&state=open", headers=headers)
        
        if resp.status_code == 200:
            issues = resp.json()
            for issue in issues:
                if "pull_request" in issue:
                    continue  # Skip pull requests
                
                issue_num = issue.get("number")
                title = issue.get("title", "")
                repo_name = issue.get("repository", {}).get("name", "GitHub")
                body = issue.get("body", "") or f"Imported from {repo_name} issue #{issue_num}"

                # Check if task already exists
                existing = await db.execute(select(Task).where(Task.github_issue_number == issue_num))
                if existing.scalar_one_or_none():
                    continue

                # Match project by repo name if exists
                p_res = await db.execute(select(Project).where(func.lower(Project.name).contains(repo_name.lower())))
                project = p_res.scalars().first()

                new_task = Task(
                    title=f"[{repo_name}] {title}",
                    description=body[:500],
                    priority="high" if any(l.get("name", "").lower() in ("bug", "urgent") for l in issue.get("labels", [])) else "medium",
                    status="todo",
                    github_issue_number=issue_num,
                    project_id=project.id if project else None,
                )
                db.add(new_task)
                imported_count += 1

            await db.commit()

    return {"status": "ok", "imported_tasks": imported_count}


# ==========================================
# GOOGLE OAUTH2 (Calendar + Gmail)
# ==========================================

GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
GOOGLE_USERINFO_URL = "https://www.googleapis.com/oauth2/v2/userinfo"
GOOGLE_SCOPES = "https://www.googleapis.com/auth/calendar.readonly https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile"


from urllib.parse import urlencode

@router.get("/google/auth-url")
async def google_auth_url():
    """Generate the Google OAuth2 authorization URL."""
    if not settings.GOOGLE_CLIENT_ID:
        raise HTTPException(
            status_code=400,
            detail="Google OAuth is not configured. Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in .env"
        )

    redirect_uri = "http://localhost:8000/api/v1/integrations/google/callback"
    params = {
        "client_id": settings.GOOGLE_CLIENT_ID,
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": GOOGLE_SCOPES,
        "access_type": "offline",
        "prompt": "consent",
        "state": "nucleus-google-auth",
    }
    url = f"{GOOGLE_AUTH_URL}?{urlencode(params)}"
    return {"auth_url": url}


@router.get("/google/callback")
async def google_callback(code: str, state: str = "", db: AsyncSession = Depends(get_db)):
    """
    Google redirects here with ?code=xxx after user grants permission.
    Exchanges the code for access + refresh tokens.
    """
    if not settings.GOOGLE_CLIENT_ID or not settings.GOOGLE_CLIENT_SECRET:
        raise HTTPException(status_code=400, detail="Google OAuth not configured")

    redirect_uri = "http://localhost:8000/api/v1/integrations/google/callback"

    async with httpx.AsyncClient() as client:
        # Exchange code for tokens
        token_response = await client.post(
            GOOGLE_TOKEN_URL,
            data={
                "client_id": settings.GOOGLE_CLIENT_ID,
                "client_secret": settings.GOOGLE_CLIENT_SECRET,
                "code": code,
                "redirect_uri": redirect_uri,
                "grant_type": "authorization_code",
            },
        )

        if token_response.status_code != 200:
            raise HTTPException(status_code=400, detail="Failed to exchange Google code for token")

        token_data = token_response.json()
        access_token = token_data.get("access_token")
        refresh_token = token_data.get("refresh_token")
        expires_in = token_data.get("expires_in", 3600)

        if not access_token:
            raise HTTPException(status_code=400, detail=f"Google error: {token_data.get('error_description', 'Unknown error')}")

        # Fetch user profile
        user_response = await client.get(
            GOOGLE_USERINFO_URL,
            headers={"Authorization": f"Bearer {access_token}"},
        )
        user_data = user_response.json() if user_response.status_code == 200 else {}

    # Store or update token
    result = await db.execute(select(IntegrationToken).where(IntegrationToken.service_name == "google"))
    existing = result.scalar_one_or_none()

    metadata = {
        "email": user_data.get("email", ""),
        "name": user_data.get("name", ""),
        "picture": user_data.get("picture", ""),
        "scopes": GOOGLE_SCOPES.split(" "),
    }

    expires_at = datetime.utcnow() + timedelta(seconds=expires_in)

    if existing:
        existing.access_token = access_token
        existing.refresh_token = refresh_token or existing.refresh_token
        existing.expires_at = expires_at
        existing.metadata_json = metadata
        existing.updated_at = datetime.utcnow()
    else:
        token_record = IntegrationToken(
            service_name="google",
            access_token=access_token,
            refresh_token=refresh_token,
            expires_at=expires_at,
            metadata_json=metadata,
        )
        db.add(token_record)

    await db.commit()

    email = user_data.get("email", "unknown")
    return HTMLResponse(content=f"""
    <html>
    <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body {{ background: #000; color: #fff; font-family: -apple-system, system-ui, sans-serif;
                   display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }}
            .card {{ text-align: center; padding: 40px; background: #1c1c1e; border-radius: 20px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); max-width: 320px; }}
            .check {{ font-size: 56px; margin-bottom: 12px; }}
            h2 {{ margin: 0 0 8px 0; font-size: 22px; font-weight: 700; }}
            p {{ color: #8e8e93; font-size: 14px; margin: 4px 0 24px 0; line-height: 1.4; }}
            .btn {{ display: inline-block; background: #34c759; color: #fff; font-weight: 600; text-decoration: none; padding: 14px 28px; border-radius: 12px; font-size: 15px; width: 80%; }}
        </style>
    </head>
    <body>
        <div class="card">
            <div class="check">✅</div>
            <h2>Google Connected!</h2>
            <p>Signed in as <strong>{email}</strong></p>
            <a class="btn" href="nucleus://auth/callback">Open Nucleus App</a>
        </div>
        <script>
            setTimeout(function() {{
                window.location.href = "nucleus://auth/callback";
            }}, 800);
        </script>
    </body>
    </html>
    """)


@router.post("/google/disconnect")
async def google_disconnect(db: AsyncSession = Depends(get_db)):
    """Disconnect Google by removing the stored tokens."""
    result = await db.execute(select(IntegrationToken).where(IntegrationToken.service_name == "google"))
    token = result.scalar_one_or_none()
    if token:
        await db.delete(token)
        await db.commit()
    return {"status": "disconnected", "service": "google"}


@router.get("/google/calendar/events")
async def google_calendar_events(db: AsyncSession = Depends(get_db)):
    """Fetch upcoming Google Calendar events."""
    result = await db.execute(select(IntegrationToken).where(IntegrationToken.service_name == "google"))
    token = result.scalar_one_or_none()

    if not token:
        raise HTTPException(status_code=401, detail="Google not connected")

    # Refresh token if expired
    if token.expires_at and token.expires_at < datetime.utcnow():
        token = await _refresh_google_token(token, db)

    async with httpx.AsyncClient() as client:
        now = datetime.utcnow().isoformat() + "Z"
        resp = await client.get(
            "https://www.googleapis.com/calendar/v3/calendars/primary/events",
            params={
                "timeMin": now,
                "maxResults": 10,
                "singleEvents": True,
                "orderBy": "startTime",
            },
            headers={"Authorization": f"Bearer {token.access_token}"},
        )

        if resp.status_code == 401:
            # Token expired, try refresh
            token = await _refresh_google_token(token, db)
            resp = await client.get(
                "https://www.googleapis.com/calendar/v3/calendars/primary/events",
                params={"timeMin": now, "maxResults": 10, "singleEvents": True, "orderBy": "startTime"},
                headers={"Authorization": f"Bearer {token.access_token}"},
            )

        if resp.status_code != 200:
            raise HTTPException(status_code=502, detail="Failed to fetch calendar events")

        data = resp.json()
        events = []
        for item in data.get("items", []):
            events.append({
                "id": item.get("id", ""),
                "summary": item.get("summary", "Untitled Event"),
                "start": item.get("start", {}).get("dateTime", item.get("start", {}).get("date", "")),
                "end": item.get("end", {}).get("dateTime", item.get("end", {}).get("date", "")),
                "location": item.get("location", ""),
                "htmlLink": item.get("htmlLink", ""),
                "hangoutLink": item.get("hangoutLink", ""),
                "status": item.get("status", "confirmed"),
            })

    return {"events": events}


@router.get("/google/gmail/messages")
async def google_gmail_messages(db: AsyncSession = Depends(get_db)):
    """Fetch recent Gmail messages and unread email count."""
    result = await db.execute(select(IntegrationToken).where(IntegrationToken.service_name == "google"))
    token = result.scalar_one_or_none()

    if not token:
        raise HTTPException(status_code=401, detail="Google not connected")

    if token.expires_at and token.expires_at < datetime.utcnow():
        token = await _refresh_google_token(token, db)

    async with httpx.AsyncClient() as client:
        headers = {"Authorization": f"Bearer {token.access_token}"}

        # Fetch list of messages
        list_resp = await client.get(
            "https://gmail.googleapis.com/gmail/v1/users/me/messages",
            params={"maxResults": 10, "q": "in:inbox"},
            headers=headers,
        )

        if list_resp.status_code == 401:
            token = await _refresh_google_token(token, db)
            headers = {"Authorization": f"Bearer {token.access_token}"}
            list_resp = await client.get(
                "https://gmail.googleapis.com/gmail/v1/users/me/messages",
                params={"maxResults": 10, "q": "in:inbox"},
                headers=headers,
            )

        if list_resp.status_code != 200:
            raise HTTPException(status_code=502, detail="Failed to fetch Gmail messages")

        list_data = list_resp.json()
        raw_messages = list_data.get("messages", [])

        # Count unread messages
        unread_resp = await client.get(
            "https://gmail.googleapis.com/gmail/v1/users/me/messages",
            params={"q": "is:unread in:inbox", "maxResults": 1},
            headers=headers,
        )
        unread_count = 0
        if unread_resp.status_code == 200:
            unread_count = unread_resp.json().get("resultSizeEstimate", 0)

        messages = []
        for msg_item in raw_messages[:8]:
            msg_id = msg_item.get("id")
            detail_resp = await client.get(
                f"https://gmail.googleapis.com/gmail/v1/users/me/messages/{msg_id}",
                params={"format": "full"},
                headers=headers,
            )
            if detail_resp.status_code == 200:
                detail = detail_resp.json()
                snippet = detail.get("snippet", "")
                label_ids = detail.get("labelIds", [])
                is_unread = "UNREAD" in label_ids

                payload = detail.get("payload", {})
                headers_list = payload.get("headers", [])

                subject = "No Subject"
                sender = "Unknown Sender"
                date_str = ""

                for h in headers_list:
                    h_name = h.get("name", "").lower()
                    if h_name == "subject":
                        subject = h.get("value", "No Subject")
                    elif h_name == "from":
                        sender = h.get("value", "Unknown Sender")
                    elif h_name == "date":
                        date_str = h.get("value", "")

                messages.append({
                    "id": msg_id,
                    "subject": subject,
                    "from": sender,
                    "snippet": snippet,
                    "date": date_str,
                    "is_unread": is_unread,
                })

    return {
        "unread_count": unread_count,
        "total_messages": len(messages),
        "messages": messages,
    }


@router.get("/google/summary")
async def google_summary(db: AsyncSession = Depends(get_db)):
    """Fetch combined Google Calendar events & Gmail unread count for Dashboard."""
    result = await db.execute(select(IntegrationToken).where(IntegrationToken.service_name == "google"))
    token = result.scalar_one_or_none()

    if not token:
        return {"connected": False, "events_today": [], "unread_emails": 0}

    if token.expires_at and token.expires_at < datetime.utcnow():
        try:
            token = await _refresh_google_token(token, db)
        except Exception:
            return {"connected": False, "events_today": [], "unread_emails": 0}

    events = []
    unread_emails = 0

    async with httpx.AsyncClient() as client:
        headers = {"Authorization": f"Bearer {token.access_token}"}
        now = datetime.utcnow().isoformat() + "Z"

        # Fetch calendar events
        try:
            cal_resp = await client.get(
                "https://www.googleapis.com/calendar/v3/calendars/primary/events",
                params={"timeMin": now, "maxResults": 5, "singleEvents": True, "orderBy": "startTime"},
                headers=headers,
            )
            if cal_resp.status_code == 200:
                for item in cal_resp.json().get("items", []):
                    events.append({
                        "id": item.get("id", ""),
                        "summary": item.get("summary", "Untitled Event"),
                        "start": item.get("start", {}).get("dateTime", item.get("start", {}).get("date", "")),
                        "end": item.get("end", {}).get("dateTime", item.get("end", {}).get("date", "")),
                        "hangoutLink": item.get("hangoutLink", ""),
                    })
        except Exception:
            pass

        # Fetch unread emails count
        try:
            gmail_resp = await client.get(
                "https://gmail.googleapis.com/gmail/v1/users/me/messages",
                params={"q": "is:unread in:inbox", "maxResults": 1},
                headers=headers,
            )
            if gmail_resp.status_code == 200:
                unread_emails = gmail_resp.json().get("resultSizeEstimate", 0)
        except Exception:
            pass

    return {
        "connected": True,
        "email": token.metadata_json.get("email", ""),
        "events_today": events,
        "unread_emails": unread_emails,
    }


# --- Helpers ---

async def _refresh_google_token(token: IntegrationToken, db: AsyncSession) -> IntegrationToken:
    """Refresh an expired Google access token using the refresh token."""
    if not token.refresh_token:
        raise HTTPException(status_code=401, detail="Google refresh token missing. Please reconnect Google.")

    async with httpx.AsyncClient() as client:
        resp = await client.post(
            GOOGLE_TOKEN_URL,
            data={
                "client_id": settings.GOOGLE_CLIENT_ID,
                "client_secret": settings.GOOGLE_CLIENT_SECRET,
                "refresh_token": token.refresh_token,
                "grant_type": "refresh_token",
            },
        )
        if resp.status_code != 200:
            raise HTTPException(status_code=401, detail="Failed to refresh Google token. Please reconnect.")

        data = resp.json()
        token.access_token = data["access_token"]
        token.expires_at = datetime.utcnow() + timedelta(seconds=data.get("expires_in", 3600))
        token.updated_at = datetime.utcnow()
        await db.commit()

    return token


def _is_today(timestamp_str: str) -> bool:
    """Check if a GitHub timestamp is from today."""
    try:
        ts = datetime.fromisoformat(timestamp_str.replace("Z", "+00:00"))
        return ts.date() == datetime.utcnow().date()
    except (ValueError, AttributeError):
        return False
