from __future__ import annotations

from dataclasses import dataclass
import json
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

from .errors import ContractError, G0Error


@dataclass(frozen=True)
class GenerationResult:
    response: dict[str, Any] | None
    schema_valid: bool
    error: str | None
    prompt_eval_count: int
    eval_count: int
    done_reason: str
    total_duration_ns: int
    wall_duration_seconds: float


class OllamaClient:
    def __init__(self, base_url: str = "http://127.0.0.1:11434", timeout_seconds: int = 180) -> None:
        parsed = urllib.parse.urlparse(base_url)
        if parsed.scheme != "http" or parsed.hostname not in {"127.0.0.1", "localhost", "::1"}:
            raise ContractError("Ollama base URL must be loopback HTTP")
        self._base_url = base_url.rstrip("/")
        self._timeout_seconds = timeout_seconds

    @property
    def base_url(self) -> str:
        return self._base_url

    def version(self) -> str:
        return str(self._request("GET", "/api/version").get("version", "unknown"))

    def tags(self) -> dict[str, dict[str, Any]]:
        payload = self._request("GET", "/api/tags")
        return {item["name"]: item for item in payload.get("models", [])}

    def show(self, model: str) -> dict[str, Any]:
        return self._request("POST", "/api/show", {"model": model})

    def running_models(self) -> list[dict[str, Any]]:
        return list(self._request("GET", "/api/ps").get("models", []))

    def generate(
        self,
        *,
        model: str,
        prompt: str,
        schema: dict[str, Any],
        options: dict[str, Any],
        think: bool | None,
    ) -> GenerationResult:
        body: dict[str, Any] = {
            "model": model,
            "prompt": prompt,
            "format": schema,
            "stream": False,
            "options": options,
        }
        if think is not None:
            body["think"] = think
        start = time.perf_counter()
        try:
            payload = self._request("POST", "/api/generate", body)
            wall_duration = time.perf_counter() - start
            response_text = payload.get("response", "")
            try:
                response = json.loads(response_text)
                schema_valid = isinstance(response, dict)
                error = None if schema_valid else "response_not_object"
            except json.JSONDecodeError:
                response = None
                schema_valid = False
                error = "invalid_json"
            return GenerationResult(
                response=response,
                schema_valid=schema_valid,
                error=error,
                prompt_eval_count=int(payload.get("prompt_eval_count", 0)),
                eval_count=int(payload.get("eval_count", 0)),
                done_reason=str(payload.get("done_reason", "unknown")),
                total_duration_ns=int(payload.get("total_duration", 0)),
                wall_duration_seconds=wall_duration,
            )
        except G0Error as error:
            return GenerationResult(None, False, str(error), 0, 0, "error", 0, time.perf_counter() - start)

    def embed(self, model: str, inputs: list[str]) -> dict[str, Any]:
        return self._request("POST", "/api/embed", {"model": model, "input": inputs})

    def _request(self, method: str, path: str, body: dict[str, Any] | None = None) -> dict[str, Any]:
        data = None if body is None else json.dumps(body, ensure_ascii=False).encode("utf-8")
        request = urllib.request.Request(
            self._base_url + path,
            data=data,
            method=method,
            headers={"Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(request, timeout=self._timeout_seconds) as response:
                return json.load(response)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
            raise G0Error(f"Ollama request failed for {path}: {error}") from error
