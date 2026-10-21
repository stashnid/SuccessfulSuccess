"""Local smoke commands: make llm-hello and make parse TEXT='...'."""

import argparse
import json
import os
from datetime import datetime

from anthropic import AnthropicBedrock, AnthropicBedrockMantle

from app.ai.agenda import parse_agenda
from app.config import settings


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["hello", "parse"])
    parser.add_argument("--text", default=os.getenv("TEXT", ""))
    args = parser.parse_args()
    client = (
        AnthropicBedrock(aws_region=settings.cognito_region)
        if settings.parser_model.startswith("us.anthropic.")
        else AnthropicBedrockMantle(aws_region=settings.cognito_region)
    )
    if args.command == "hello":
        options = {
            "model": settings.parser_model,
            "max_tokens": 80,
            "messages": [{"role": "user", "content": "In one sentence: what is an ISO week?"}],
        }
        if "-5-5" in settings.parser_model:
            options["output_config"] = {"effort": "low"}
        response = client.messages.create(**options)
        print(" ".join(block.text for block in response.content if block.type == "text"))
        print(response.stop_reason, response.usage.input_tokens, response.usage.output_tokens)
        return
    if not args.text.strip():
        parser.error("--text is required for parse")
    now = datetime.now(settings.tz)
    agenda, usage = parse_agenda(
        args.text,
        now.date(),
        settings.app_timezone,
        client=client,
        model=settings.parser_model,
    )
    print(
        json.dumps({"agenda": agenda.model_dump(mode="json"), "usage": usage}, ensure_ascii=False)
    )


if __name__ == "__main__":
    main()
