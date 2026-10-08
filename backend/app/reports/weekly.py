"""Build a deterministic CSV report for one ISO week from the meetings database."""

import csv
import io
import re
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import settings
from app.db import SessionFactory
from app.models import Meeting, User

WEEK_PATTERN = re.compile(r"^(\d{4})-W(\d{2})$")


def week_start(week: str, timezone: ZoneInfo | None = None) -> datetime:
    """Return Monday midnight in the application's timezone for an ISO week."""
    match = WEEK_PATTERN.fullmatch(week)
    if match is None:
        raise ValueError("week must have the form YYYY-Www")
    try:
        monday = datetime.fromisocalendar(int(match[1]), int(match[2]), 1)
    except ValueError as exc:
        raise ValueError(f"invalid ISO week: {week}") from exc
    return monday.replace(tzinfo=timezone or settings.tz)


def previous_week(week: str) -> str:
    previous_monday = week_start(week) - timedelta(days=7)
    year, number, _ = previous_monday.isocalendar()
    return f"{year}-W{number:02d}"


def previous_iso_week(now: datetime | None = None) -> str:
    local_now = (now or datetime.now(settings.tz)).astimezone(settings.tz)
    previous_monday = local_now.date() - timedelta(days=local_now.weekday() + 7)
    year, number, _ = previous_monday.isocalendar()
    return f"{year}-W{number:02d}"


def report_key(week: str) -> str:
    week_start(week)
    return f"reports/{week}.csv"


def _hours(meetings: list[Meeting]) -> float:
    return sum((meeting.ends_at - meeting.starts_at).total_seconds() for meeting in meetings) / 3600


def render_weekly_report(
    week: str, meetings: list[Meeting], owner_labels: dict[str, str] | None = None
) -> bytes:
    """Render queried meetings as UTF-8 CSV; the same data yields the same bytes."""
    start = week_start(week)
    end = start + timedelta(weeks=1)
    prior_week = previous_week(week)
    prior_start = week_start(prior_week)
    current = [meeting for meeting in meetings if start <= meeting.starts_at < end]
    prior = [meeting for meeting in meetings if prior_start <= meeting.starts_at < start]
    current_hours = _hours(current)
    prior_hours = _hours(prior)
    owner_labels = owner_labels or {}

    output = io.StringIO(newline="")
    writer = csv.writer(output, lineterminator="\n")
    writer.writerow(
        [
            "section",
            "week",
            "meetings",
            "total_hours",
            "change_meetings",
            "change_hours",
            "title",
            "start",
            "duration_hours",
            "participants",
            "person",
        ]
    )
    writer.writerow(
        [
            "summary",
            week,
            len(current),
            f"{current_hours:.2f}",
            len(current) - len(prior),
            f"{current_hours - prior_hours:+.2f}",
            "",
            "",
            "",
            "",
            "",
        ]
    )
    writer.writerow(
        ["previous_week", prior_week, len(prior), f"{prior_hours:.2f}", "", "", "", "", "", "", ""]
    )
    longest = sorted(
        current,
        key=lambda meeting: (
            -(meeting.ends_at - meeting.starts_at).total_seconds(),
            meeting.starts_at,
            meeting.name,
        ),
    )[:5]
    for meeting in longest:
        local_start = meeting.starts_at.astimezone(settings.tz)
        owner_id = getattr(meeting, "owner_id", None)
        writer.writerow(
            [
                "longest",
                week,
                "",
                "",
                "",
                "",
                meeting.name,
                local_start.isoformat(),
                f"{(meeting.ends_at - meeting.starts_at).total_seconds() / 3600:.2f}",
                len(meeting.participants),
                owner_labels.get(owner_id, owner_id or ""),
            ]
        )

    owners = sorted(
        {meeting.owner_id for meeting in meetings if getattr(meeting, "owner_id", None)}
    )
    for owner_id in owners:
        owner_current = [meeting for meeting in current if meeting.owner_id == owner_id]
        owner_prior = [meeting for meeting in prior if meeting.owner_id == owner_id]
        writer.writerow(
            [
                "per_person",
                week,
                len(owner_current),
                f"{_hours(owner_current):.2f}",
                len(owner_current) - len(owner_prior),
                f"{_hours(owner_current) - _hours(owner_prior):+.2f}",
                "",
                "",
                "",
                "",
                owner_labels.get(owner_id, owner_id),
            ]
        )
    return output.getvalue().encode("utf-8")


async def build_weekly_report(week: str, session: AsyncSession | None = None) -> bytes:
    """Query meetings for an ISO week and its predecessor, then return CSV bytes."""
    start = week_start(previous_week(week))
    end = week_start(week) + timedelta(weeks=1)

    async def query(active_session: AsyncSession) -> bytes:
        result = await active_session.scalars(
            select(Meeting)
            .options(selectinload(Meeting.participants))
            .where(Meeting.starts_at >= start, Meeting.starts_at < end)
        )
        meetings = list(result)
        owner_ids = {meeting.owner_id for meeting in meetings if meeting.owner_id}
        owner_labels = {}
        if owner_ids:
            users = await active_session.execute(
                select(User.id, User.email, User.name).where(User.id.in_(owner_ids))
            )
            owner_labels = {user_id: email or name or user_id for user_id, email, name in users}
        return render_weekly_report(week, meetings, owner_labels)

    if session is not None:
        return await query(session)
    async with SessionFactory() as owned_session:
        return await query(owned_session)
