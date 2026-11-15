from __future__ import annotations

import ast
import os
from pathlib import Path
import platform
import shutil
import socket
import subprocess
import sys
from typing import Any
import urllib.parse

from .manifest import validate_manifest


BLOCKED_DB_IMPORTS = {"psycopg", "psycopg2", "asyncpg", "sqlalchemy", "npgsql"}


def run_preflight(module_root: Path, workspace_root: Path, artifact_root: Path) -> dict[str, Any]:
    required_models = artifact_root / "ollama-models"
    checks: list[dict[str, Any]] = []

    def check(name: str, passed: bool, detail: str, *, hard: bool = True) -> None:
        checks.append({"name": name, "passed": passed, "hard": hard, "detail": detail})

    check("python_3_12", sys.version_info[:2] == (3, 12), platform.python_version())
    check("artifact_git_ignored", _is_ignored(workspace_root, artifact_root), str(artifact_root))
    check("no_db_dependencies", _has_no_db_imports(module_root), "AST imports and requirements.lock")

    c_free = _free_bytes(Path("C:/"))
    d_free = _free_bytes(Path("D:/"))
    check("c_drive_free", c_free >= 3 * 1024**3, f"{c_free / 1024**3:.2f} GiB")
    check("d_drive_free", d_free >= 15 * 1024**3, f"{d_free / 1024**3:.2f} GiB")

    configured_models = os.environ.get("OLLAMA_MODELS")
    configured_path = Path(configured_models).resolve() if configured_models else None
    check("ollama_models_on_d", configured_path == required_models.resolve(), configured_models or "not set")
    no_cloud = os.environ.get("OLLAMA_NO_CLOUD")
    check("ollama_cloud_disabled", no_cloud == "1", no_cloud or "not set")

    host = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434")
    parsed = urllib.parse.urlparse(host if "://" in host else f"http://{host}")
    check("ollama_loopback_config", parsed.hostname in {"127.0.0.1", "localhost", "::1"}, host)
    ollama_path = shutil.which("ollama")
    local_ollama = artifact_root / "ollama-app" / "ollama.exe"
    if ollama_path is None and local_ollama.is_file():
        ollama_path = str(local_ollama)
    check("ollama_installed", ollama_path is not None, ollama_path or "not found")
    check("ollama_loopback_listening", _port_open(parsed.hostname or "127.0.0.1", parsed.port or 11434), host)
    try:
        lan_address = socket.gethostbyname(socket.gethostname())
    except OSError:
        lan_address = "unknown"
    lan_open = lan_address not in {"unknown", "127.0.0.1"} and _port_open(lan_address, parsed.port or 11434)
    check("ollama_not_listening_on_lan", not lan_open, lan_address)
    default_model_root = Path.home() / ".ollama" / "models"
    default_model_bytes = sum(path.stat().st_size for path in default_model_root.rglob("*") if path.is_file()) if default_model_root.exists() else 0
    check("no_models_on_c_default", default_model_bytes == 0, f"{default_model_bytes} bytes in {default_model_root}")

    try:
        records = validate_manifest(module_root / "config" / "source-manifest.json", workspace_root)
        check("manifest_valid", True, f"{len(records)} source revisions")
    except Exception as error:
        check("manifest_valid", False, str(error))

    gpu = _command_output(["nvidia-smi", "--query-gpu=name,memory.total,driver_version", "--format=csv,noheader"])
    ram = _memory_bytes()
    return {
        "gate_passed": all(item["passed"] for item in checks if item["hard"]),
        "checks": checks,
        "environment": {
            "platform": platform.platform(),
            "python_executable": sys.executable,
            "ram_gib": round(ram / 1024**3, 2) if ram else None,
            "gpu": gpu,
            "artifact_root": str(artifact_root),
        },
    }


def _is_ignored(workspace_root: Path, artifact_root: Path) -> bool:
    result = subprocess.run(
        ["git", "check-ignore", "--quiet", str(artifact_root)],
        cwd=workspace_root,
        check=False,
        capture_output=True,
    )
    return result.returncode == 0


def _has_no_db_imports(module_root: Path) -> bool:
    lock = (module_root / "requirements.lock").read_text(encoding="utf-8").casefold()
    if any(name in lock for name in BLOCKED_DB_IMPORTS):
        return False
    for path in (module_root / "src").rglob("*.py"):
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                names = [item.name.split(".")[0].casefold() for item in node.names]
            elif isinstance(node, ast.ImportFrom) and node.module:
                names = [node.module.split(".")[0].casefold()]
            else:
                continue
            if BLOCKED_DB_IMPORTS.intersection(names):
                return False
    return True


def _free_bytes(root: Path) -> int:
    try:
        return shutil.disk_usage(root).free
    except OSError:
        return 0


def _port_open(host: str, port: int) -> bool:
    try:
        with socket.create_connection((host, port), timeout=0.5):
            return True
    except OSError:
        return False


def _command_output(command: list[str]) -> str | None:
    try:
        result = subprocess.run(command, check=False, capture_output=True, text=True, timeout=10)
        return result.stdout.strip() if result.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def _memory_bytes() -> int | None:
    if os.name != "nt":
        return None
    import ctypes

    class MemoryStatusEx(ctypes.Structure):
        _fields_ = [
            ("dwLength", ctypes.c_ulong),
            ("dwMemoryLoad", ctypes.c_ulong),
            ("ullTotalPhys", ctypes.c_ulonglong),
            ("ullAvailPhys", ctypes.c_ulonglong),
            ("ullTotalPageFile", ctypes.c_ulonglong),
            ("ullAvailPageFile", ctypes.c_ulonglong),
            ("ullTotalVirtual", ctypes.c_ulonglong),
            ("ullAvailVirtual", ctypes.c_ulonglong),
            ("ullAvailExtendedVirtual", ctypes.c_ulonglong),
        ]

    status = MemoryStatusEx()
    status.dwLength = ctypes.sizeof(status)
    return status.ullTotalPhys if ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(status)) else None
