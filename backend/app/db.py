"""Database engine, session factory and the FastAPI session dependency."""

import json
import os
from collections.abc import AsyncIterator

import boto3
from app.config import settings
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.pool import NullPool


class Base(DeclarativeBase):
    """Declarative base for every ORM model."""


def _database_url() -> str:
    """Resolve the report Lambda's database URL without exposing it in its environment."""
    secret_arn = os.getenv("DATABASE_SECRET_ARN")
    if not secret_arn:
        return settings.database_url
    secret = boto3.client("secretsmanager").get_secret_value(SecretId=secret_arn)
    return json.loads(secret["SecretString"])["url"]


# Lambda execution environments can stay warm after a request. Releasing every
# connection avoids keeping the remote pooler (or an idle Aurora) active.
engine_options = {"poolclass": NullPool} if os.getenv("AWS_LAMBDA_FUNCTION_NAME") else {}
engine = create_async_engine(_database_url(), echo=False, pool_pre_ping=True, **engine_options)

SessionFactory = async_sessionmaker(engine, expire_on_commit=False, autoflush=False)


async def get_session() -> AsyncIterator[AsyncSession]:
    """Yield a session and roll back if the request handler raises."""
    async with SessionFactory() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
