import pytest
from app import app  # מייבא את האפליקציה

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_home(client):
    response = client.get("/")
    assert response.status_code == 200
    assert b"Hello from DevOps Project" in response.data
