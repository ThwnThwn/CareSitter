"""Local artifact boundary and integrity helpers; hashes are not reviewer authentication."""
from __future__ import annotations

import os
from pathlib import Path
import uuid
from typing import Any

from .errors import ManualGraphError
from .jsonio import content_sha256, file_sha256, serialized_json_bytes


def sign(value: dict) -> dict:
    unsigned = {k: v for k, v in value.items() if k != "content_sha256"}
    return {**unsigned, "content_sha256": content_sha256(unsigned)}


def verify(value: Any, mode: str) -> None:
    if not isinstance(value, dict) or value.get("schema_version") != 1 or value.get("mode") != mode:
        raise ManualGraphError(f"invalid artifact: {mode}")
    if value.get("content_sha256") != sign(value)["content_sha256"]:
        raise ManualGraphError(f"tampered artifact: {mode}")


def local_path(workspace: Path, path: Path) -> Path:
    root = (workspace / "backend/artifacts/nutrition-knowledge-local").resolve()
    resolved = (workspace / path).resolve()
    if not resolved.is_relative_to(root):
        raise ManualGraphError("retrieval artifacts must remain inside the local artifact directory")
    return resolved


def write_once(path: Path, value: dict) -> None:
    """Exclusive creation persists consumption before evaluation; failures stay consumed."""
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        with path.open("xb") as stream:
            stream.write(serialized_json_bytes(value))
            stream.flush()
            os.fsync(stream.fileno())
    except FileExistsError:
        raise ManualGraphError("artifact already exists; holdout may already be consumed") from None


def write_once_atomic(path: Path, value: dict) -> None:
    """Publish a complete new artifact without exposing a partially written final path."""
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    try:
        with temporary.open("xb") as stream:
            stream.write(serialized_json_bytes(value))
            stream.flush()
            os.fsync(stream.fileno())
        os.link(temporary, path)
    except FileExistsError:
        raise ManualGraphError("artifact already exists; use a new revision") from None
    finally:
        temporary.unlink(missing_ok=True)


def code_identity() -> dict:
    # Bind the complete package, including CLI/gates, rather than a mutable Git HEAD alone.
    root = Path(__file__).parent
    files = {p.name: file_sha256(p) for p in sorted(root.glob("*.py"))}
    return {"files": files, "sha256": content_sha256(files)}
