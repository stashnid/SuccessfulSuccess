"""Boundary and ranking checks for the CSV report."""

import csv
import io
from datetime import datetime, timedelta
from types import SimpleNamespace
from zoneinfo import ZoneInfo

import pytest

from app.models import Meeting, Participant, User
from app.reports.weekly import (
    build_weekly_report,
    previous_week,
    render_weekly_report,
    report_key,
    week_start,
)

KYIV = ZoneInfo("Europe/Kyiv")


def meeting(name: str, start: datetime, hours: float, participants: int = 0):
    return SimpleNamespace(
        name=name,
        starts_at=start,
        ends_at=start + timedelta(hours=hours),
        participants=[object()] * participants,
    )


def test_year_boundary_and_invalid_week():
    assert previous_week("2026-W01") == "2025-W52"
    assert report_key("2026-W01") == "reports/2026-W01.csv"
    with pytest.raises(ValueError):
        week_start("2026-W54")


def test_summary_and_five_longest_are_stable():
    start = datetime(2026, 10, 5, tzinfo=KYIV)
    meetings = [meeting("Previous", start - timedelta(days=1), 2)]
    meetings += [
        meeting(f"Current {hours}", start + timedelta(hours=hours), hours, hours)
        for hours in range(1, 7)
    ]
    csv_bytes = render_weekly_report("2026-W41", meetings)
    rows = list(csv.DictReader(io.StringIO(csv_bytes.decode("utf-8"))))

    assert rows[0]["meetings"] == "6"
    assert rows[0]["total_hours"] == "21.00"
    assert rows[0]["change_meetings"] == "5"
    assert rows[0]["change_hours"] == "+19.00"
    assert rows[1]["week"] == "2026-W40"
    assert [row["title"] for row in rows[2:]] == [f"Current {hours}" for hours in range(6, 1, -1)]
    assert rows[2]["participants"] == "6"
    assert csv_bytes == render_weekly_report("2026-W41", list(reversed(meetings)))


@pytest.mark.asyncio
async def test_report_queries_real_postgres(session):
    start = datetime(2026, 10, 5, tzinfo=KYIV)
    session.add(User(id="report-owner", auth_provider="cognito"))
    await session.flush()
    session.add_all(
        [
            Meeting(
                owner_id="report-owner",
                name="Long meeting",
                starts_at=start,
                ends_at=start + timedelta(hours=2),
                participants=[Participant(name="One", position=0)],
            ),
            Meeting(
                owner_id="report-owner",
                name="Prior meeting",
                starts_at=start - timedelta(days=1),
                ends_at=start - timedelta(days=1) + timedelta(hours=1),
            ),
        ]
    )
    await session.commit()

    result = await build_weekly_report("2026-W41", session)
    rows = list(csv.DictReader(io.StringIO(result.decode("utf-8"))))
    assert rows[0]["meetings"] == "1"
    assert rows[0]["total_hours"] == "2.00"
    assert rows[1]["meetings"] == "1"
    assert rows[2]["title"] == "Long meeting"
    assert rows[2]["participants"] == "1"
    assert rows[3]["section"] == "per_person"
    assert rows[3]["person"] == "report-owner"
