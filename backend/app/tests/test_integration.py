
import time, httpx
from fastapi.testclient import TestClient
from app.main import app
c=TestClient(app)
def wait(url,tries=30):
  for _ in range(tries):
    try: return httpx.get(url,timeout=1).status_code
    except: time.sleep(0.5)
  return 0
def test_broker():
  r=c.post("/api/broker2",json={"client_id":"pytest","auth_token":"tok"})
  assert r.status_code==200
  d=c.get("/api/broker2").json()
  assert d["brokers"][0]["client_id"]=="pytest"
def test_frontend_auth():
  assert wait("http://frontend:3000") in (200,301,302,307,308)

