from __future__ import annotations

import ipaddress
import json
import re
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, ProxyHandler, Request, build_opener

from .embedding_index import normalized
from .errors import ManualGraphError


class _NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ManualGraphError("Ollama redirects are forbidden")


class OllamaEncoder:
    """Loopback-only embeddings with digest verification around every inference."""

    def __init__(self, endpoint: str, digest: str, dimension: int = 1024,
                 model: str = "bge-m3:latest"):
        parsed = urlsplit(endpoint)
        try:
            loopback = ipaddress.ip_address(parsed.hostname or "").is_loopback
        except ValueError:
            loopback = False
        if (not loopback or parsed.scheme != "http" or parsed.username or parsed.password
                or parsed.query or parsed.fragment or parsed.path not in {"", "/"}):
            raise ManualGraphError("Ollama endpoint must be a literal loopback HTTP address")
        if model != "bge-m3:latest" or not re.fullmatch(r"[a-f0-9]{64}", digest):
            raise ManualGraphError("bge-m3 requires a pinned SHA-256 model digest")
        if dimension != 1024:
            raise ManualGraphError("bge-m3 dimension must be 1024")
        self.endpoint, self.model, self.digest, self.dimension = endpoint.rstrip("/"), model, digest, dimension
        self._opener = build_opener(ProxyHandler({}), _NoRedirect())
        self._verify_model()

    def _request(self, route: str, payload: dict | None = None) -> dict:
        body = None if payload is None else json.dumps(payload).encode("utf-8")
        try:
            with self._opener.open(Request(self.endpoint + route, data=body,
                    headers={"Content-Type": "application/json"}), timeout=60) as response:
                raw = response.read(16 * 1024 * 1024 + 1)
                if len(raw) > 16 * 1024 * 1024:
                    raise ManualGraphError("Ollama response exceeds size limit")
                result = json.loads(raw)
                if not isinstance(result, dict):
                    raise ManualGraphError("invalid Ollama response")
                return result
        except (HTTPError, URLError, TimeoutError, ValueError):
            # Avoid provider bodies that may echo book text or future patient inputs.
            raise ManualGraphError("Ollama local request failed; check service and pinned model") from None

    def _verify_model(self) -> None:
        models = self._request("/api/tags").get("models", [])
        if not any(m.get("name") == self.model and m.get("digest") == self.digest for m in models):
            raise ManualGraphError("Ollama model digest mismatch or model missing")

    def encode(self, texts: list[str]) -> list[list[float]]:
        if not texts or len(texts) > 32 or any(not t.strip() or len(t) > 32000 for t in texts):
            raise ManualGraphError("embedding input is empty or exceeds local bounds")
        self._verify_model()
        response = self._request("/api/embed", {"model": self.model, "input": texts,
                                  "truncate": False, "keep_alive": "5m"})
        self._verify_model()
        vectors = response.get("embeddings")
        if not isinstance(vectors, list) or len(vectors) != len(texts):
            raise ManualGraphError("Ollama returned an unexpected embedding count")
        return [normalized(vector, self.dimension) for vector in vectors]
