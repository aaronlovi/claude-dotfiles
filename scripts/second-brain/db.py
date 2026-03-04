"""Shared database connection for second brain scripts."""

import os
from pathlib import Path
from dotenv import load_dotenv
import psycopg

# Load .env from this directory
_env_path = Path(__file__).resolve().parent / ".env"
load_dotenv(_env_path)

SCHEMA = "second_brain"
TABLE = f"{SCHEMA}.project_knowledge"

def connect() -> psycopg.Connection:
    return psycopg.connect(
        host=os.environ.get("SECOND_BRAIN_DB_HOST", "localhost"),
        port=int(os.environ.get("SECOND_BRAIN_DB_PORT", "5456")),
        user=os.environ.get("SECOND_BRAIN_DB_USER", "postgres"),
        password=os.environ.get("SECOND_BRAIN_DB_PASSWORD", "postgres"),
        dbname=os.environ.get("SECOND_BRAIN_DB_NAME", "postgres"),
        autocommit=True,
    )
