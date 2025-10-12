#!/bin/bash
set -euo pipefail

# ==============================================================
# AlgoDatta Demo Stack (Cognito/Dummy)
# Backend: FastAPI + SQLite
# Frontend: Next.js (App Router)
# Features: Header/Footer, Login Guard, Broker Integration
# Backend pytest
# Clean • Error-free • Idempotent • POSIX-safe
# ==============================================================

say() { echo -e "$1"; }
ok()  { echo -e "✅ $1"; }
info(){ echo -e "ℹ️  $1"; }
warn(){ echo -e "⚠️  $1"; }
step(){ echo -e "\n$1"; }
ensure_dir() { mkdir -p "$1"; }

PROJECT_ROOT="AlgoDatta_Spec1_Build_Steps_v2_Cognito"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

say "🚀 Building AlgoDatta stack at: $PROJECT_ROOT"

# ---------------------------------------------------------------
# Ensure structure (POSIX-safe loop; no brace/array expansion)
# ---------------------------------------------------------------
for d in \
  backend/app/api backend/app/models backend/app/tests backend/vol \
  frontend/public frontend/components \
  frontend/app/auth/login frontend/app/api/auth/dummy \
  frontend/app/dashboard/broker frontend/app/dashboard/strategies \
  frontend/app/dashboard/executions frontend/app/dashboard/reports \
  frontend/app/dashboard/about frontend/app/dashboard/contact
do
  ensure_dir "$PROJECT_ROOT/$d"
done

# ---------------------------------------------------------------
# Logo (non-destructive)
# ---------------------------------------------------------------
if [ -f "$BASE_DIR/algodatta-logo-png.png" ]; then
  cp -f "$BASE_DIR/algodatta-logo-png.png" "$PROJECT_ROOT/frontend/public/logo.png"
elif [ ! -f "$PROJECT_ROOT/frontend/public/logo.png" ]; then
  printf 'PNG' > "$PROJECT_ROOT/frontend/public/logo.png"
fi

# ==============================================================
# Backend (FastAPI + SQLite + Pytest)
# ==============================================================
cat > "$PROJECT_ROOT/backend/Dockerfile" <<'EOF'
FROM python:3.11-slim
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
RUN apt-get update && apt-get install -y --no-install-recommends build-essential curl && rm -rf /var/lib/apt/lists/*
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt
COPY . /app
RUN mkdir -p /app/data
EXPOSE 8000
CMD ["uvicorn","app.main:app","--host","0.0.0.0","--port","8000"]
EOF

cat > "$PROJECT_ROOT/backend/requirements.txt" <<'EOF'
fastapi==0.112.2
uvicorn[standard]==0.30.6
requests==2.32.3
SQLAlchemy==2.0.36
pytest==8.3.3
httpx==0.27.0
EOF

cat > "$PROJECT_ROOT/backend/app/db.py" <<'EOF'
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

DB_URL = os.getenv("DATABASE_URL", "sqlite:////app/data/app.db")
os.makedirs("/app/data", exist_ok=True)

engine = create_engine(DB_URL, connect_args={"check_same_thread": False} if DB_URL.startswith("sqlite") else {})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
EOF

cat > "$PROJECT_ROOT/backend/app/models/broker.py" <<'EOF'
from sqlalchemy import String, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import Mapped, mapped_column
from app.db import Base

class Broker(Base):
    __tablename__ = "brokers"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    broker_name: Mapped[str] = mapped_column(String, nullable=False)
    client_id: Mapped[str] = mapped_column(String, nullable=False)
    auth_token: Mapped[str] = mapped_column(String, nullable=False)
    connected_at: Mapped[str] = mapped_column(DateTime(timezone=True), server_default=func.now())
EOF

cat > "$PROJECT_ROOT/backend/app/api/broker_persist.py" <<'EOF'
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from app.db import get_db
from app.models.broker import Broker
from datetime import datetime

router = APIRouter()

@router.post("/broker2")
def link_broker(payload: dict, db: Session = Depends(get_db)):
    name = payload.get("broker_name")
    cid = payload.get("client_id")
    tok = payload.get("auth_token")
    if not name or not cid or not tok:
        raise HTTPException(status_code=400, detail="broker_name, client_id and auth_token required")
    existing = db.query(Broker).first()
    if existing:
        existing.broker_name, existing.client_id, existing.auth_token, existing.connected_at = name, cid, tok, datetime.utcnow()
    else:
        db.add(Broker(broker_name=name, client_id=cid, auth_token=tok))
    db.commit()
    return {"status": f"Broker {name} linked"}

@router.get("/broker2")
def get_broker(db: Session = Depends(get_db)):
    b = db.query(Broker).first()
    return {"brokers": [] if not b else [{
        "broker_name": b.broker_name,
        "client_id": b.client_id,
        "auth_token": b.auth_token,
        "connected_at": b.connected_at.isoformat() if b.connected_at else ""
    }]}
EOF

cat > "$PROJECT_ROOT/backend/app/api/health.py" <<'EOF'
from fastapi import APIRouter
router = APIRouter()
@router.get("/healthz")
def healthz(): return {"status": "ok"}
EOF

cat > "$PROJECT_ROOT/backend/app/main.py" <<'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api import health, broker_persist
from app.db import Base, engine

app = FastAPI(title="AlgoDatta API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000","http://frontend:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
Base.metadata.create_all(bind=engine)
app.include_router(health.router, prefix="/api")
app.include_router(broker_persist.router, prefix="/api")
EOF

cat > "$PROJECT_ROOT/backend/.env" <<'EOF'
DATABASE_URL=sqlite:////app/data/app.db
EOF

# Ensure Python package markers (idempotent)
touch "$PROJECT_ROOT/backend/app/__init__.py"
touch "$PROJECT_ROOT/backend/app/api/__init__.py"
touch "$PROJECT_ROOT/backend/app/models/__init__.py"
touch "$PROJECT_ROOT/backend/app/tests/__init__.py"

# Backend tests (pytest)
cat > "$PROJECT_ROOT/backend/app/tests/test_broker.py" <<'EOF'
import sys, os
sys.path.append(os.path.dirname(os.path.dirname(__file__)))  # add backend/app to sys.path
from main import app
from fastapi.testclient import TestClient

client = TestClient(app)

def test_health():
    r = client.get("/api/healthz")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"

def test_broker_link_and_fetch():
    r = client.post("/api/broker2", json={"broker_name":"pytest","client_id":"cid","auth_token":"tok"})
    assert r.status_code == 200
    data = client.get("/api/broker2").json()
    assert data["brokers"][0]["broker_name"] == "pytest"
EOF

# ==============================================================
# Frontend (Next.js App Router)
# ==============================================================

# Dockerfile for Next.js
cat > "$PROJECT_ROOT/frontend/Dockerfile" <<'EOF'
# ---- deps ----
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json ./package.json
RUN npm install --legacy-peer-deps || true

# ---- build ----
FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_DISABLE_ESLINT=1 NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# ---- runtime ----
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY public ./public
EXPOSE 3000
CMD ["npm", "start"]
EOF

# package.json
cat > "$PROJECT_ROOT/frontend/package.json" <<'EOF'
{
  "name": "algodatta-frontend",
  "version": "0.1.0",
  "scripts": {
    "dev": "next dev -p 3000",
    "build": "next build",
    "start": "next start -p 3000"
  },
  "dependencies": {
    "next": "14.2.5",
    "react": "18.3.1",
    "react-dom": "18.3.1"
  }
}
EOF

# next.config.js
cat > "$PROJECT_ROOT/frontend/next.config.js" <<'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = { reactStrictMode: true };
module.exports = nextConfig;
EOF

# Root Layout with Header & Footer
cat > "$PROJECT_ROOT/frontend/app/layout.tsx" <<'EOF'
import Header from "../components/Header";
import Footer from "../components/Footer";

export const metadata = { title: "AlgoDatta" };

export default function RootLayout({children}:{children:React.ReactNode}){
  return (
    <html lang="en">
      <body style={{margin:0,fontFamily:"Inter,Arial"}}>
        <Header />
        {children}
        <Footer />
      </body>
    </html>
  );
}
EOF

# Header component (consistent across all pages)
cat > "$PROJECT_ROOT/frontend/components/Header.tsx" <<'EOF'
"use client";
import Image from "next/image";
import { usePathname } from "next/navigation";

export default function Header(){
  const pathname = usePathname();
  const logout = ()=>{ document.cookie="id_token=; Max-Age=0; path=/"; window.location.href="/login"; };
  const linkStyle=(p:string)=>({
    color:"#dcf1ff", marginRight:16, textDecoration:"none",
    fontWeight: pathname===p ? 700 : 400,
    borderBottom: pathname===p ? "2px solid #fff" : "none",
    paddingBottom: 4
  });
  return (
    <div style={{background:"#0c3c60",height:96,display:"flex",alignItems:"center",justifyContent:"center",position:"relative"}}>
      <div style={{position:"absolute",left:24,top:24}}>
        <a href="/dashboard" style={linkStyle("/dashboard")}>Dashboard</a>
        <a href="/dashboard/strategies" style={linkStyle("/dashboard/strategies")}>Strategies</a>
        <a href="/dashboard/executions" style={linkStyle("/dashboard/executions")}>Executions</a>
        <a href="/dashboard/reports" style={linkStyle("/dashboard/reports")}>Reports</a>
        <a href="/dashboard/broker" style={linkStyle("/dashboard/broker")}>Broker</a>
        <a href="/dashboard/about" style={linkStyle("/dashboard/about")}>About</a>
        <a href="/dashboard/contact" style={linkStyle("/dashboard/contact")}>Contact</a>
      </div>
      <div style={{display:"flex",flexDirection:"column",alignItems:"center",background:"#fff",padding:"10px 24px",borderRadius:38}}>
        <Image src="/logo.png" width={48} height={48} alt="AlgoDatta"/>
        <div style={{color:"#0c3c60",fontWeight:700,marginTop:4}}>AlgoDatta</div>
      </div>
      <div style={{position:"absolute",right:24}}>
        <button onClick={logout} style={{background:"#fff",color:"#0c3c60",border:"none",borderRadius:8,padding:"10px 16px",cursor:"pointer"}}>Logout</button>
      </div>
    </div>
  );
}
EOF

# Footer component (copyright across all pages)
cat > "$PROJECT_ROOT/frontend/components/Footer.tsx" <<'EOF'
export default function Footer(){
  return (
    <div style={{background:"#0c3c60",height:80,marginTop:16,display:"flex",alignItems:"center",justifyContent:"center",color:"#d8e6f5"}}>
      <div style={{display:"flex",gap:28}}>
        <span>About Us</span><span>Contact Us</span><span>Copyright © AlgoDatta</span>
      </div>
    </div>
  );
}
EOF

# Middleware: login guard
cat > "$PROJECT_ROOT/frontend/middleware.ts" <<'EOF'
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export function middleware(req: NextRequest) {
  const token=req.cookies.get("id_token");
  const url=req.nextUrl;
  if (url.pathname === "/") return NextResponse.redirect(new URL("/login", url));
  if (url.pathname.startsWith("/dashboard") && !token) return NextResponse.redirect(new URL("/login", url));
  return NextResponse.next();
}
export const config = { matcher: ["/", "/dashboard/:path*"] };
EOF

# Login page (dummy hosted UI)
cat > "$PROJECT_ROOT/frontend/app/auth/login/page.tsx" <<'EOF'
"use client";
export default function LoginPage(){
  const login=()=>{ window.location.href="/api/auth/dummy"; };
  return (
    <div style={{minHeight:"100vh",display:"flex",justifyContent:"center",alignItems:"center"}}>
      <div style={{background:"#fff",padding:32,borderRadius:12,boxShadow:"0 4px 20px rgba(0,0,0,0.12)",textAlign:"center"}}>
        <img src="/logo.png" width="100" height="100" alt="AlgoDatta"/>
        <h1 style={{margin:"16px 0",color:"#0c3c60"}}>AlgoDatta</h1>
        <button onClick={login} style={{width:"100%",padding:12,background:"#0c3c60",color:"#fff",border:"none",borderRadius:6}}>
          Login
        </button>
      </div>
    </div>
  );
}
EOF

# Dummy login route -> sets cookie then redirects to /dashboard
cat > "$PROJECT_ROOT/frontend/app/api/auth/dummy/route.ts" <<'EOF'
import { NextRequest, NextResponse } from "next/server";
export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(req: NextRequest) {
  const res = NextResponse.redirect(new URL("/dashboard", req.url));
  res.cookies.set("id_token","dummy-token",{ httpOnly: true, sameSite: "lax", path: "/" });
  return res;
}
export {};
EOF

# Dashboard + About + Contact
cat > "$PROJECT_ROOT/frontend/app/dashboard/page.tsx" <<'EOF'
export default function Dashboard(){
  return <div style={{padding:40}}>Welcome to AlgoDatta Dashboard</div>;
}
EOF

cat > "$PROJECT_ROOT/frontend/app/dashboard/about/page.tsx" <<'EOF'
export default function About(){
  return (
    <div style={{padding:40}}>
      <h2>About Us</h2>
      <p>AlgoDatta is a demo algorithmic trading platform prototype used for testing UI and API integration. (Dummy data)</p>
    </div>
  );
}
EOF

cat > "$PROJECT_ROOT/frontend/app/dashboard/contact/page.tsx" <<'EOF'
export default function Contact(){
  return (
    <div style={{padding:40}}>
      <h2>Contact Us</h2>
      <p>Email: support@algodatta.com (dummy)</p>
      <p>Phone: +91-99999-99999 (dummy)</p>
    </div>
  );
}
EOF

# Broker Integration page (Broker Name + Client ID + Access Token)
cat > "$PROJECT_ROOT/frontend/app/dashboard/broker/page.tsx" <<'EOF'
"use client";
import { useEffect, useState } from "react";
type Broker = { broker_name:string; client_id:string; auth_token:string; connected_at:string };

export default function BrokerIntegration(){
  const [brokerName, setBrokerName] = useState("");
  const [clientId, setClientId] = useState("");
  const [accessToken, setAccessToken] = useState("");
  const [status, setStatus] = useState<"idle"|"success"|"error">("idle");
  const [broker, setBroker] = useState<Broker | null>(null);
  const api = process.env.NEXT_PUBLIC_API_BASE || "http://localhost:8000";

  async function refresh(){
    try{
      const r = await fetch(`${api}/api/broker2`);
      if (r.ok) {
        const d = await r.json();
        setBroker(d.brokers && d.brokers.length ? d.brokers[0] : null);
      }
    }catch{}
  }

  async function submit(){
    try{
      const r = await fetch(`${api}/api/broker2`, {
        method: "POST",
        headers: {"Content-Type":"application/json"},
        body: JSON.stringify({ broker_name: brokerName, client_id: clientId, auth_token: accessToken })
      });
      setStatus(r.ok ? "success" : "error");
      if (r.ok) { await refresh(); }
    }catch{ setStatus("error"); }
  }

  useEffect(()=>{ refresh(); },[]);

  return (
    <div style={{padding:40}}>
      <h2>Broker Integration</h2>
      <input placeholder="Broker Name" value={brokerName} onChange={e=>setBrokerName(e.target.value)}
             style={{display:"block",width:"100%",padding:12,marginBottom:12,border:"1px solid #cfd7e6",borderRadius:6}}/>
      <input placeholder="Client ID" value={clientId} onChange={e=>setClientId(e.target.value)}
             style={{display:"block",width:"100%",padding:12,marginBottom:12,border:"1px solid #cfd7e6",borderRadius:6}}/>
      <input type="password" placeholder="Access Token" value={accessToken} onChange={e=>setAccessToken(e.target.value)}
             style={{display:"block",width:"100%",padding:12,marginBottom:20,border:"1px solid #cfd7e6",borderRadius:6}}/>
      <button onClick={submit} style={{width:"100%",padding:12,background:"#0c3c60",color:"#fff",border:"none",borderRadius:6}}>
        Submit
      </button>
      {status==="success" && <p style={{color:"green",marginTop:12}}>Integration with {brokerName} Successful ✔</p>}
      {status==="error"   && <p style={{color:"red",marginTop:12}}>Integration with {brokerName} Failed ❌</p>}
      <div style={{marginTop:24}}>
        <h4>Linked Broker</h4>
        {!broker ? <p style={{opacity:.7}}>No broker linked yet.</p> :
          <div style={{border:"1px solid #e6ebf2",borderRadius:8,padding:12}}>
            <div><strong>Broker:</strong> {broker.broker_name}</div>
            <div><strong>Client ID:</strong> {broker.client_id}</div>
            <div><strong>Access Token:</strong> ••••••••••</div>
            <div style={{fontSize:"0.85em",color:"#666"}}><strong>Linked at:</strong> {broker.connected_at}</div>
          </div>}
      </div>
    </div>
  );
}
EOF

# Frontend env (API base)
cat > "$PROJECT_ROOT/frontend/.env.local" <<'EOF'
NEXT_PUBLIC_API_BASE=http://localhost:8000
EOF

# ==============================================================
# Docker Compose (persistent DB volume)
# ==============================================================
cat > "$PROJECT_ROOT/docker-compose.yml" <<'EOF'
services:
  backend:
    build: ./backend
    env_file: ./backend/.env
    ports: ["8000:8000"]
    volumes:
      - ./backend/vol:/app/data
  frontend:
    build: ./frontend
    depends_on: [backend]
    ports: ["3000:3000"]
EOF

# ==============================================================
# Build + Start + Tests + Basic Checks
# ==============================================================
step "🔧 Building & starting containers…"
docker compose -f "$PROJECT_ROOT/docker-compose.yml" up -d --build

step "🧪 Running backend pytest inside container…"
docker compose -f "$PROJECT_ROOT/docker-compose.yml" exec -T backend pytest -q || warn "Tests failed!"

step "🔍 Post-start checks…"
sleep 2
if curl -s http://localhost:8000/api/healthz | grep -q '"status":"ok"'; then
  ok "Backend health ok"
else
  warn "Backend health check failed"
fi

if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200"; then
  ok "Frontend reachable (http://localhost:3000)"
else
  warn "Frontend not reachable yet"
fi

say "\n🎉 All set!
- Open http://localhost:3000 → login (dummy) → /dashboard
- Header & Footer consistent across all pages (copyright shown)
- About Us & Contact Us pages present with dummy data
- Broker page supports Broker Name + Client ID + Access Token, shows success/failure
- All /dashboard pages are login guarded
- Backend pytest validates /api/healthz and /api/broker2
"