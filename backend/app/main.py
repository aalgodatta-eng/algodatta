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

# Safe schema reset (idempotent)
Base.metadata.drop_all(bind=engine, checkfirst=True)
Base.metadata.create_all(bind=engine, checkfirst=True)

app.include_router(health.router, prefix="/api")
app.include_router(broker_persist.router, prefix="/api")
