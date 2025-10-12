from fastapi import APIRouter, Depends
from app.core.auth import get_current_user

router = APIRouter()

@router.get("/strategies")
def list_strategies(user=Depends(get_current_user)):
    name = user.get("cognito:username") or user.get("username") or "user"
    return {"msg": f"Hello {name}, here are your strategies"}
