"""Public Function URL handler. Cognito access token is required before any model call."""

from __future__ import annotations

import asyncio
import json
import logging
import time
from datetime import date
from functools import lru_cache
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from anthropic import AnthropicBedrock, AnthropicBedrockMantle, RateLimitError

from app.ai.agenda import PROMPT_VERSION, AgendaParseError, parse_agenda
from app.auth import AuthError, get_verifier
from app.config import settings

log = logging.getLogger("meetings.agenda")
log.setLevel(logging.INFO)

# Lab 6 handout's per-million-token list prices. The log is an estimate; AWS
# billing is authoritative and may differ by endpoint, tier, or future pricing.
TOKEN_PRICES = {
    "us.anthropic.claude-haiku-4-5-20251001-v1:0": (1.10, 5.50),
    "anthropic.claude-opus-5-5": (4.00, 20.00),
    "anthropic.claude-sonnet-5-5": (2.00, 10.00),
    "anthropic.claude-haiku-5-5": (0.10, 0.50),
}


@lru_cache
def _client() -> AnthropicBedrock | AnthropicBedrockMantle:
    if settings.parser_model.startswith("us.anthropic."):
        return AnthropicBedrock(aws_region=settings.cognito_region)
    return AnthropicBedrockMantle(aws_region=settings.cognito_region)


def _json(status: int, body: dict) -> dict:
    return {
        "statusCode": status,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(body, ensure_ascii=False),
    }


def _cost(model: str, usage: dict[str, int]) -> float | None:
    prices = TOKEN_PRICES.get(model)
    if prices is None:
        return None
    return round((usage["input_tokens"] * prices[0] + usage["output_tokens"] * prices[1]) / 1e6, 8)


def _parse_body(raw: str) -> tuple[str, date, str]:
    payload = json.loads(raw)
    if not isinstance(payload, dict):
        raise ValueError("Expected a JSON object.")
    text = payload.get("text")
    if not isinstance(text, str) or not text.strip():
        raise ValueError("Paste some agenda text first.")
    if len(text) > 10_000:
        raise OverflowError("Agenda text must be 10,000 characters or fewer.")
    today = date.fromisoformat(payload["today"])
    tz = payload["tz"]
    if not isinstance(tz, str) or len(tz) > 64:
        raise ValueError("Invalid time zone.")
    ZoneInfo(tz)
    return text, today, tz


def handler(event: dict, context: object) -> dict:
    headers = {key.lower(): value for key, value in (event.get("headers") or {}).items()}
    authorization = headers.get("authorization", "")
    if not authorization.startswith("Bearer "):
        return _json(401, {"error": "Sign in to continue."})
    try:
        user = asyncio.run(get_verifier().verify(authorization[7:]))
    except AuthError:
        return _json(401, {"error": "Your session has expired. Sign in again."})
    except Exception:
        log.exception("Cognito verification failed")
        return _json(503, {"error": "Authentication is temporarily unavailable."})

    try:
        text, today, tz = _parse_body(event.get("body") or "")
    except OverflowError as exc:
        return _json(413, {"error": str(exc)})
    except (KeyError, TypeError, ValueError, json.JSONDecodeError, ZoneInfoNotFoundError):
        return _json(400, {"error": "Provide text, today's date and a valid time zone."})

    started = time.monotonic()
    try:
        agenda, usage = parse_agenda(
            text, today, tz, client=_client(), model=settings.parser_model
        )
    except AgendaParseError as exc:
        log.info(
            json.dumps(
                {
                    "event": "agenda_parse_failed",
                    "user": user.sub,
                    "model": settings.parser_model,
                    "prompt_version": PROMPT_VERSION,
                    **exc.usage,
                    "latency_ms": int((time.monotonic() - started) * 1000),
                    "cost_usd": _cost(settings.parser_model, exc.usage),
                    "cost_basis": "estimated_list_price",
                }
            )
        )
        return _json(422, {"error": "No valid agenda was found. Edit it manually."})
    except RateLimitError:
        return _json(429, {"error": "The parser is busy. Try again shortly."})
    except Exception:
        log.exception("Bedrock agenda parse failed")
        return _json(503, {"error": "The parser is temporarily unavailable."})

    log.info(
        json.dumps(
            {
                "event": "agenda_parsed",
                "user": user.sub,
                "model": settings.parser_model,
                "prompt_version": PROMPT_VERSION,
                **usage,
                "latency_ms": int((time.monotonic() - started) * 1000),
                "cost_usd": _cost(settings.parser_model, usage),
                "cost_basis": "estimated_list_price",
            }
        )
    )
    return _json(
        200,
        {
            "agenda": agenda.model_dump(mode="json"),
            "model": settings.parser_model,
            "prompt_version": PROMPT_VERSION,
        },
    )
