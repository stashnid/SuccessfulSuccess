"""One-off transfer of the existing ECS database into the Aurora schema."""

from datetime import datetime
from uuid import UUID

from sqlalchemy.dialects.postgresql import insert

from app.db import SessionFactory
from app.models import Meeting, Participant, User


def _timestamp(value: str | None) -> datetime | None:
    return datetime.fromisoformat(value) if value else None


async def import_legacy_data(data: dict) -> dict[str, int]:
    """Upsert a consistent source snapshot; safe to repeat just before cutover."""
    users = data.get("users", [])
    meetings = data.get("meetings", [])
    participants = data.get("participants", [])
    async with SessionFactory() as session, session.begin():
        for row in users:
            values = {
                **row,
                "created_at": _timestamp(row["created_at"]),
                "updated_at": _timestamp(row["updated_at"]),
                "last_login_at": _timestamp(row.get("last_login_at")),
            }
            statement = insert(User).values(**values)
            await session.execute(
                statement.on_conflict_do_update(
                    index_elements=[User.id],
                    set_={key: value for key, value in values.items() if key != "id"},
                )
            )
        for row in meetings:
            values = {
                **row,
                "id": UUID(row["id"]),
                "starts_at": _timestamp(row["starts_at"]),
                "ends_at": _timestamp(row["ends_at"]),
                "created_at": _timestamp(row["created_at"]),
                "updated_at": _timestamp(row["updated_at"]),
            }
            statement = insert(Meeting).values(**values)
            await session.execute(
                statement.on_conflict_do_update(
                    index_elements=[Meeting.id],
                    set_={key: value for key, value in values.items() if key != "id"},
                )
            )
        for row in participants:
            values = {
                **row,
                "id": UUID(row["id"]),
                "meeting_id": UUID(row["meeting_id"]),
            }
            statement = insert(Participant).values(**values)
            await session.execute(
                statement.on_conflict_do_update(
                    index_elements=[Participant.id],
                    set_={key: value for key, value in values.items() if key != "id"},
                )
            )
    return {"users": len(users), "meetings": len(meetings), "participants": len(participants)}
