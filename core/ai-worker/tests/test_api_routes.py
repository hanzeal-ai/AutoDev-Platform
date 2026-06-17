from fastapi.testclient import TestClient

from autodev_ai.main import app


def test_workflow_replaced_single_step_generate_routes():
    client = TestClient(app)

    for path in (
        "/generate/stage",
        "/generate/report",
        "/generate/chat",
        "/generate/chat/stream",
        "/generate/prd",
        "/generate/development",
        "/generate/development/coding",
    ):
        response = client.post(path, json={})
        assert response.status_code == 404
