#!/usr/bin/env python3
"""Copy the current ECS/Supabase rows to the private Aurora Lambda.

Only counts are printed. The temporary payload is owner-readable and is removed
after the Lambda invocation; the source password never appears in an argument.
"""

import json
import os
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import unquote, urlparse

REGION = os.environ.get("AWS_REGION", "us-east-1")
SOURCE_TASK = os.environ.get("ECS_TASK_DEFINITION", "spry-backend-task")
TARGET_FUNCTION = os.environ.get("LAMBDA_FUNCTION", "successfulsuccess-backend")


def run(*args: str, env: dict | None = None) -> str:
    result = subprocess.run(args, env=env, capture_output=True, text=True, check=True)
    return result.stdout


def main() -> None:
    task = json.loads(
        run(
            "aws",
            "ecs",
            "describe-task-definition",
            "--region",
            REGION,
            "--task-definition",
            SOURCE_TASK,
            "--output",
            "json",
        )
    )["taskDefinition"]
    variables = task["containerDefinitions"][0]["environment"]
    url = next(item["value"] for item in variables if item["name"] == "DATABASE_URL")
    parsed = urlparse(url.replace("postgresql+asyncpg://", "postgresql://", 1))
    if not parsed.hostname or not parsed.username or not parsed.password:
        raise ValueError("source task lacks a complete database URL")
    pg_env = os.environ.copy()
    pg_env.update(
        PGHOST=parsed.hostname,
        PGPORT=str(parsed.port or 5432),
        PGUSER=unquote(parsed.username),
        PGPASSWORD=unquote(parsed.password),
        PGDATABASE=parsed.path.lstrip("/"),
        PGSSLMODE="require",
    )
    query = """
        select json_build_object(
          'users', (select coalesce(json_agg(row_to_json(u)), '[]'::json) from public.users u),
          'meetings', (select coalesce(json_agg(row_to_json(m)), '[]'::json) from public.meetings m),
          'participants', (select coalesce(json_agg(row_to_json(p)), '[]'::json) from public.participants p)
        )
    """
    data = json.loads(run("psql", "-X", "-A", "-t", "-c", query, env=pg_env))
    counts = {
        table: len(data[table]) for table in ("users", "meetings", "participants")
    }
    print("Source row counts:", counts)
    previous_umask = os.umask(0o077)
    try:
        with tempfile.TemporaryDirectory(prefix="spry-transfer-") as directory:
            payload = Path(directory) / "payload.json"
            response = Path(directory) / "response.json"
            payload.write_text(json.dumps({"action": "import_legacy", "data": data}))
            invocation = json.loads(
                run(
                    "aws",
                    "lambda",
                    "invoke",
                    "--region",
                    REGION,
                    "--function-name",
                    TARGET_FUNCTION,
                    "--cli-binary-format",
                    "raw-in-base64-out",
                    "--payload",
                    f"fileb://{payload}",
                    "--output",
                    "json",
                    str(response),
                )
            )
            result = json.loads(response.read_text())
            if invocation.get("FunctionError") or result.get("status") != "imported":
                raise RuntimeError(
                    "Aurora import failed; inspect the backend Lambda logs"
                )
            print("Imported row counts:", result["counts"])
    finally:
        os.umask(previous_umask)


if __name__ == "__main__":
    main()
