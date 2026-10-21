"""API-level tests for the meetings endpoints."""

import uuid


async def test_create_meeting_returns_201_with_ordered_participants(client, meeting_payload):
    response = await client.post("/api/v1/meetings", json=meeting_payload)

    assert response.status_code == 201, response.text
    body = response.json()
    assert uuid.UUID(body["id"])
    assert body["name"] == "Sprint planning"
    assert [p["name"] for p in body["participants"]] == ["Ostap", "Iryna"]
    assert [p["position"] for p in body["participants"]] == [0, 1]
    assert response.headers["Location"] == f"/api/v1/meetings/{body['id']}"


async def test_create_rejects_end_before_start(client, meeting_payload):
    meeting_payload["ends_at"] = meeting_payload["starts_at"]

    response = await client.post("/api/v1/meetings", json=meeting_payload)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


async def test_create_rejects_blank_name(client, meeting_payload):
    meeting_payload["name"] = "   "

    response = await client.post("/api/v1/meetings", json=meeting_payload)

    assert response.status_code == 422
    assert response.json()["error"]["details"][0]["field"] == "name"


async def test_create_rejects_duplicate_participant(client, meeting_payload):
    meeting_payload["participants"] = [
        {"name": "Ostap", "email": "ostap@example.com"},
        {"name": "ostap", "email": "OSTAP@example.com"},
    ]

    response = await client.post("/api/v1/meetings", json=meeting_payload)

    assert response.status_code == 422
    assert "duplicate participant" in response.json()["error"]["message"]


async def test_create_rejects_naive_datetime(client, meeting_payload):
    meeting_payload["starts_at"] = "2026-09-10T10:00:00"

    response = await client.post("/api/v1/meetings", json=meeting_payload)

    assert response.status_code == 422


async def test_get_unknown_meeting_returns_404_envelope(client):
    response = await client.get(f"/api/v1/meetings/{uuid.uuid4()}")

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"


async def test_delete_removes_meeting_and_participants(client, session, meeting_payload):
    created = (await client.post("/api/v1/meetings", json=meeting_payload)).json()

    deleted = await client.delete(f"/api/v1/meetings/{created['id']}")
    assert deleted.status_code == 204

    assert (await client.get(f"/api/v1/meetings/{created['id']}")).status_code == 404

    from sqlalchemy import func, select

    from app.models import Participant

    remaining = await session.scalar(
        select(func.count()).select_from(Participant).where(Participant.meeting_id == created["id"])
    )
    assert remaining == 0


async def test_update_replaces_fields_and_participants(client, meeting_payload):
    created = (await client.post("/api/v1/meetings", json=meeting_payload)).json()
    meeting_payload["name"] = "Sprint review"
    meeting_payload["location"] = "  "
    meeting_payload["participants"] = [{"name": "Iryna"}, {"name": "Taras"}]

    response = await client.put(f"/api/v1/meetings/{created['id']}", json=meeting_payload)

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["id"] == created["id"]
    assert body["name"] == "Sprint review"
    assert body["location"] is None
    assert [(p["name"], p["position"]) for p in body["participants"]] == [
        ("Iryna", 0),
        ("Taras", 1),
    ]
    fetched = (await client.get(f"/api/v1/meetings/{created['id']}")).json()
    assert [p["name"] for p in fetched["participants"]] == ["Iryna", "Taras"]


async def test_update_unknown_meeting_returns_404(client, meeting_payload):
    response = await client.put(f"/api/v1/meetings/{uuid.uuid4()}", json=meeting_payload)

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"


async def test_update_rejects_end_before_start(client, meeting_payload):
    created = (await client.post("/api/v1/meetings", json=meeting_payload)).json()
    meeting_payload["ends_at"] = meeting_payload["starts_at"]

    response = await client.put(f"/api/v1/meetings/{created['id']}", json=meeting_payload)

    assert response.status_code == 422


async def test_health_reports_database_ok(client):
    response = await client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "database": "ok", "version": "1.0.0"}


async def test_save_agenda_keeps_reviewed_version_and_original_suggestion(client, meeting_payload):
    created = (await client.post("/api/v1/meetings", json=meeting_payload)).json()
    suggestion = {
        "title": "Pricing review",
        "starts_at": None,
        "duration_minutes": 45,
        "items": [{"topic": "Pro plans", "owner": "Taras", "minutes": 15}],
        "action_items": [],
        "language": "en",
    }
    reviewed = {**suggestion, "items": [{"topic": "Pro plans", "owner": "Olena", "minutes": 15}]}

    response = await client.put(
        f"/api/v1/meetings/{created['id']}/agenda",
        json={
            "agenda": reviewed,
            "ai_suggestion": suggestion,
            "model": "anthropic.claude-haiku-5-5",
            "prompt_version": "agenda-v1",
        },
    )

    assert response.status_code == 200, response.text
    fetched = (await client.get(f"/api/v1/meetings/{created['id']}")).json()
    assert fetched["agenda"]["items"][0]["owner"] == "Olena"
    assert fetched["ai_suggestion"]["agenda"]["items"][0]["owner"] == "Taras"


async def test_save_agenda_rejects_empty_topics(client, meeting_payload):
    created = (await client.post("/api/v1/meetings", json=meeting_payload)).json()
    response = await client.put(
        f"/api/v1/meetings/{created['id']}/agenda",
        json={"agenda": {"items": [], "language": "en"}},
    )
    assert response.status_code == 422


async def test_save_agenda_cannot_change_another_users_meeting(
    client, other_client, meeting_payload
):
    created = (await client.post("/api/v1/meetings", json=meeting_payload)).json()
    response = await other_client.put(
        f"/api/v1/meetings/{created['id']}/agenda",
        json={"agenda": {"items": [{"topic": "Changed"}], "language": "en"}},
    )
    assert response.status_code == 404
    assert (await client.get(f"/api/v1/meetings/{created['id']}")).json()["agenda"] is None
