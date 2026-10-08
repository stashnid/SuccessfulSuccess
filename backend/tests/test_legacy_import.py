"""A repeated transfer preserves rows and relationships in Aurora's schema."""

from uuid import uuid4

import pytest
from sqlalchemy import select

from app.legacy_import import import_legacy_data
from app.models import Meeting, Participant, User


@pytest.mark.asyncio
async def test_legacy_import_is_repeatable(session):
    meeting_id = str(uuid4())
    participant_id = str(uuid4())
    data = {
        "users": [
            {
                "id": "cognito-123",
                "email": "student@example.com",
                "email_verified": True,
                "name": "Student",
                "given_name": "Stu",
                "family_name": "Dent",
                "picture_url": None,
                "auth_provider": "google",
                "created_at": "2026-10-01T12:00:00+00:00",
                "updated_at": "2026-10-01T12:00:00+00:00",
                "last_login_at": None,
            }
        ],
        "meetings": [
            {
                "id": meeting_id,
                "owner_id": "cognito-123",
                "name": "Demo",
                "description": None,
                "location": None,
                "starts_at": "2026-10-02T12:00:00+00:00",
                "ends_at": "2026-10-02T13:00:00+00:00",
                "created_at": "2026-10-01T12:00:00+00:00",
                "updated_at": "2026-10-01T12:00:00+00:00",
            }
        ],
        "participants": [
            {
                "id": participant_id,
                "meeting_id": meeting_id,
                "name": "Guest",
                "email": None,
                "position": 0,
            }
        ],
    }

    assert await import_legacy_data(data) == {"users": 1, "meetings": 1, "participants": 1}
    data["meetings"][0]["name"] = "Updated demo"
    assert await import_legacy_data(data) == {"users": 1, "meetings": 1, "participants": 1}

    assert len((await session.scalars(select(User))).all()) == 1
    assert (await session.scalar(select(Meeting))).name == "Updated demo"
    assert len((await session.scalars(select(Participant))).all()) == 1
