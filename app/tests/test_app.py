import pytest
from .. import app  # כאן נניח ש-Flask הוגדר בקובץ app.py שלך

@pytest.fixture
def client():
    with app.test_client() as client:
        yield client

def test_home(client):
    response = client.get('/')
    assert response.status_code == 200
