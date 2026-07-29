# 🚀 Nucleus - Personal Omniscience & Productivity Hub

Nucleus is a self-hosted personal productivity platform managing habits, project tasks, work hours, learning roadmaps, and focus/pomodoro sessions with integrations for Gmail, Google Calendar, and GitHub.

---

## 🛠️ Tech Stack & Architecture
- **Frontend**: Flutter Multi-platform (Desktop, Web, Mobile)
- **Backend API**: FastAPI (Python 3.12)
- **Database**: PostgreSQL 16 + AsyncPG + SQLAlchemy 2.0
- **Cache**: Redis 7
- **Reverse Proxy**: Caddy 2 (Automatic HTTPS / SSL)
- **Containerization**: Docker & Docker Compose
- **Hosting Target**: Oracle Cloud Infrastructure (OCI) Always Free Tier (ARM Ampere 2 OCPUs, 12GB RAM)

---

## 📋 Step-by-Step Setup Guide

### 1️⃣ Oracle Cloud Infrastructure (OCI) Setup (Free Tier Server)

1. **Create an Oracle Cloud Account**:
   - Go to [cloud.oracle.com](https://cloud.oracle.com/) and click **Sign Up for Free Tier**.
   - Fill in your details. You will need a valid credit card for verification (Oracle places a ~$1 temporary charge and refunds it immediately; you won't be charged unless you upgrade).

2. **Provision your Free ARM Instance**:
   - In OCI Dashboard, go to **Compute** -> **Instances** -> **Create Instance**.
   - **Name**: `nucleus-server`
   - **Image and Shape**:
     - Click **Edit** under Image and Shape.
     - Select **Canonical Ubuntu 22.04 / 24.04**.
     - Under Shape, select **Ampere (ARM64)** -> **VM.Standard.A1.Flex**.
     - Set **2 OCPUs** and **12 GB RAM** (100% Free Tier eligible).
   - **Networking**: Select default VCN or create public VCN.
   - **SSH Keys**: Download both the **Private Key** (`id_rsa`) and **Public Key** to your computer.
   - Click **Create**.

3. **Open Ports (80 & 443) on Oracle Cloud Security List**:
   - Go to **Networking** -> **Virtual Cloud Networks** -> Click your VCN -> **Security Lists** -> **Default Security List**.
   - Add **Ingress Rules**:
     - **Source**: `0.0.0.0/0`, **Protocol**: TCP, **Port Range**: `80` (HTTP)
     - **Source**: `0.0.0.0/0`, **Protocol**: TCP, **Port Range**: `443` (HTTPS)

4. **Connect to Your Server via SSH**:
   ```bash
   chmod 400 ~/Downloads/id_rsa.key
   ssh -i ~/Downloads/id_rsa.key ubuntu@<YOUR_OCI_PUBLIC_IP>
   ```

5. **Install Docker on Server**:
   ```bash
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker ubuntu
   # Log out and log back in, then:
   docker compose version
   ```

---

### 2️⃣ Installing Flutter on Linux (Local Machine)

Run the following commands in your local terminal to install Flutter SDK:

```bash
# 1. Download Flutter SDK (Linux x64)
cd ~
curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.0-stable.tar.xz

# 2. Extract Flutter
tar -xf flutter_linux_3.24.0-stable.tar.xz

# 3. Add Flutter to PATH
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 4. Verify installation
flutter doctor
```

---

### 3️⃣ Running Nucleus Locally (Development)

To start the backend API and database locally:

```bash
cd /home/prabhath/projects/nucleus

# Start PostgreSQL, Redis, and FastAPI Backend
docker compose up -d --build

# Verify running containers
docker compose ps

# Check API health
curl http://localhost:8000/health
# Response: {"status":"healthy"}

# Access Interactive API Documentation (Swagger UI)
# Open http://localhost:8000/docs in your browser
```

---

### 4️⃣ Deploying to Oracle Cloud (Production)

Once your server is running:

1. Clone your repository on your OCI server:
   ```bash
   git clone https://github.com/<your-username>/nucleus.git
   cd nucleus
   ```
2. Update `Caddyfile` with your server IP or custom domain name.
3. Start production containers:
   ```bash
   docker compose -f docker-compose.prod.yml up -d --build
   ```
Your backend will be live at `https://<YOUR_OCI_PUBLIC_IP>/api/v1/` with automatic SSL!
