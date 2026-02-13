from fastapi import FastAPI
from app.api.routers import auth

app = FastAPI(title="AlgoDatta API (Local)")
app.include_router(auth.router)

@app.get("/api/healthz")
def healthz():
    return {"status": "ok"}
