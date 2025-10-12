import sys, os
sys.path.append(os.path.dirname(os.path.dirname(__file__)))
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
