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
