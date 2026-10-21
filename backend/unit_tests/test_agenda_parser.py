"""The parser must not return invalid or unreviewable model output."""

import json
from datetime import date
from types import SimpleNamespace
from unittest.mock import Mock

import pytest

from app.ai import agenda_lambda
from app.ai.agenda import AgendaParseError, parse_agenda
from app.ai.agenda_lambda import _parse_body
from app.auth import AuthError, CurrentUser


def _response(payload: dict, call_id: str = "tool-1") -> SimpleNamespace:
    return SimpleNamespace(
        content=[SimpleNamespace(type="tool_use", name="record_agenda", id=call_id, input=payload)],
        usage=SimpleNamespace(input_tokens=120, output_tokens=45),
    )


def _valid() -> dict:
    return {
        "title": "Pricing sync",
        "starts_at": "2026-10-19T10:00:00+03:00",
        "duration_minutes": 45,
        "items": [{"topic": "New Pro plans", "owner": "Олена", "minutes": 15}],
        "action_items": [],
        "language": "uk",
    }


def test_parser_returns_valid_tool_input_and_usage():
    client = Mock()
    client.messages.create.return_value = _response(_valid())

    agenda, usage = parse_agenda(
        "Пн 10:00: нові тарифи Pro — Олена, 15 хв",
        date(2026, 10, 19),
        "Europe/Kyiv",
        client=client,
        model="anthropic.claude-haiku-5-5",
    )

    assert agenda.items[0].owner == "Олена"
    assert usage == {"input_tokens": 120, "output_tokens": 45}
    assert client.messages.create.call_args.kwargs["max_tokens"] == 4096


def test_parser_retries_invalid_output_once_then_returns_correction():
    client = Mock()
    bad = _valid()
    bad["items"] = [{"topic": "New Pro plans", "owner": "Олена", "minutes": 0}]
    client.messages.create.side_effect = [_response(bad), _response(_valid(), "tool-2")]

    agenda, usage = parse_agenda(
        "Pricing sync", date(2026, 10, 19), "Europe/Kyiv",
        client=client, model="anthropic.claude-haiku-5-5",
    )

    assert agenda.items[0].minutes == 15
    assert usage == {"input_tokens": 240, "output_tokens": 90}
    assert client.messages.create.call_count == 2


def test_parser_rejects_non_agenda_after_retry():
    client = Mock()
    bad = _valid()
    bad["items"] = []
    client.messages.create.return_value = _response(bad)

    with pytest.raises(AgendaParseError) as result:
        parse_agenda(
            "milk, bread", date(2026, 10, 19), "Europe/Kyiv",
            client=client, model="anthropic.claude-haiku-5-5",
        )

    assert client.messages.create.call_count == 2
    assert result.value.usage == {"input_tokens": 240, "output_tokens": 90}


def test_parser_retries_a_response_without_a_tool_call():
    client = Mock()
    plain = SimpleNamespace(
        content=[SimpleNamespace(type="text", text="I found a meeting")],
        usage=SimpleNamespace(input_tokens=80, output_tokens=12),
    )
    client.messages.create.side_effect = [plain, _response(_valid())]

    agenda, usage = parse_agenda(
        "Pricing sync", date(2026, 10, 19), "Europe/Kyiv",
        client=client, model="anthropic.claude-haiku-5-5",
    )

    assert agenda.items[0].topic == "New Pro plans"
    assert usage == {"input_tokens": 200, "output_tokens": 57}


def test_parser_normalizes_wrong_daylight_saving_offset():
    client = Mock()
    bad = _valid()
    bad["starts_at"] = "2026-10-26T10:00:00+03:00"
    client.messages.create.return_value = _response(bad)

    agenda, usage = parse_agenda(
        "26 October at 10:00", date(2026, 10, 21), "Europe/Kyiv",
        client=client, model="us.anthropic.claude-haiku-4-5-20251001-v1:0",
    )

    assert agenda.starts_at == "2026-10-26T10:00:00+02:00"
    assert usage == {"input_tokens": 120, "output_tokens": 45}
    assert client.messages.create.call_count == 1


def test_parser_drops_invented_clock_time_for_approximate_start():
    client = Mock()
    bad = _valid()
    bad["starts_at"] = "2026-10-27T00:00:00+02:00"
    client.messages.create.return_value = _response(bad)

    agenda, _ = parse_agenda(
        "Next Tuesday after lunch: planning sync", date(2026, 10, 21), "Europe/Kyiv",
        client=client, model="us.anthropic.claude-haiku-4-5-20251001-v1:0",
    )

    assert agenda.starts_at is None


def test_lambda_rejects_long_text_before_inference():
    with pytest.raises(OverflowError):
        _parse_body(json.dumps({"text": "a" * 10_001, "today": "2026-10-19", "tz": "Europe/Kyiv"}))


def _event(text: str, token: str = "valid") -> dict:
    return {
        "headers": {"Authorization": f"Bearer {token}"},
        "body": json.dumps({"text": text, "today": "2026-10-19", "tz": "Europe/Kyiv"}),
    }


def test_lambda_rejects_anonymous_request_before_model_call(monkeypatch):
    model_call = Mock()
    monkeypatch.setattr(agenda_lambda, "parse_agenda", model_call)

    result = agenda_lambda.handler({"body": _event("Agenda")["body"]}, None)

    assert result["statusCode"] == 401
    model_call.assert_not_called()


def test_lambda_rejects_invalid_token_before_model_call(monkeypatch):
    class InvalidVerifier:
        async def verify(self, token: str) -> CurrentUser:
            raise AuthError("Invalid token")

    model_call = Mock()
    monkeypatch.setattr(agenda_lambda, "get_verifier", lambda: InvalidVerifier())
    monkeypatch.setattr(agenda_lambda, "parse_agenda", model_call)

    result = agenda_lambda.handler(_event("Agenda", "invalid"), None)

    assert result["statusCode"] == 401
    model_call.assert_not_called()


def test_lambda_rejects_large_payload_before_model_call(monkeypatch):
    class ValidVerifier:
        async def verify(self, token: str) -> CurrentUser:
            return CurrentUser(sub="test-user")

    model_call = Mock()
    monkeypatch.setattr(agenda_lambda, "get_verifier", lambda: ValidVerifier())
    monkeypatch.setattr(agenda_lambda, "parse_agenda", model_call)

    result = agenda_lambda.handler(_event("x" * 10_001), None)

    assert result["statusCode"] == 413
    model_call.assert_not_called()
