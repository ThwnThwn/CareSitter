"""Registry of every visible evaluation file/question already seen during development.

The registry only records identity (path, hashes, fingerprints). It does not mark any case
as reviewed and it never proves that a holdout is independent; it lets later gates reject
re-used questions and notice when a visible file is changed or removed.
"""
from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from .errors import ManualGraphError
from .jsonio import content_sha256, file_sha256, load_json
from .retrieval_artifacts import code_identity, sign, verify
from .retrieval_holdout import case_fingerprint

REGISTRY_MODE = "visible_evaluation_registry"
INVENTORY_MODE = "graph_repair_inventory"

# Directories (relative to the workspace) that may hold visible retrieval evaluations.
# nutrition_knowledge_g0/fixtures is deliberately absent: those are entity-extraction spans, not
# retrieval questions, and cannot be fingerprinted by question/answerability/chunk IDs.
SCAN_ROOTS = (
    "backend/services/nutrition/tools/nutrition_knowledge_manual/evaluation",
    "backend/artifacts/nutrition-knowledge-local/evaluation",
)


def build_visible_registry(workspace: Path, scan_roots: tuple[str, ...] = SCAN_ROOTS) -> dict[str, Any]:
    root = workspace.resolve()
    case_sets: list[dict[str, Any]] = []
    dependents: list[dict[str, Any]] = []
    others: list[dict[str, Any]] = []
    incompatible: list[dict[str, Any]] = []
    unreadable: list[dict[str, Any]] = []
    for relative in _scan_files(root, scan_roots):
        path = root / relative
        sha = file_sha256(path)
        try:
            document = load_json(path)
        except (OSError, ValueError) as error:
            unreadable.append({"path": relative, "file_sha256": sha, "error": type(error).__name__})
            continue
        if isinstance(document, dict) and document.get("mode") == REGISTRY_MODE:
            continue  # a registry never lists itself; otherwise every new revision drifts the previous one
        entry = {"path": relative, "file_sha256": sha}
        kind = _classify(document)
        if isinstance(document, dict) and "evaluation_content_sha256" in document:
            kind = "dependent"  # packet/ledger/report derived from a case set, not a case set itself
        if kind == "case_set":
            revision = document["corpus"]["source_revision_id"]
            cases = [{"case_id": c.get("case_id"), "fingerprint": case_fingerprint(c, revision),
                      "split": c.get("split")} for c in document["cases"]]
            case_sets.append({**entry, "source_revision_id": revision,
                              "document_content_sha256": content_sha256(document), "case_count": len(cases),
                              "cases": sorted(cases, key=lambda c: (str(c["case_id"]), c["fingerprint"]))})
        elif kind == "dependent":
            dependents.append({**entry, "references_evaluation_sha256": document["evaluation_content_sha256"]})
        elif kind == "incompatible_cases":
            incompatible.append({**entry, "case_count": len(document["cases"])})
        else:
            others.append(entry)
    known = {item["document_content_sha256"] for item in case_sets}
    # A report/ledger/packet whose evaluation hash matches no registered file is an orphan reference.
    # It stays visible rather than being treated as never-seen data.
    orphans = sorted(item["path"] for item in dependents if item["references_evaluation_sha256"] not in known)
    fingerprints = sorted({case["fingerprint"] for item in case_sets for case in item["cases"]})
    return sign({
        "schema_version": 1, "mode": REGISTRY_MODE, "scan_roots": sorted(scan_roots),
        "case_sets": case_sets, "dependent_artifacts": dependents, "other_json": others,
        "incompatible_case_files": incompatible, "unreadable": unreadable,
        "orphan_references": orphans, "visible_fingerprints": fingerprints,
        "visible_fingerprint_count": len(fingerprints),
        "complete": not unreadable and not incompatible and not orphans,
    })


def verify_visible_registry(workspace: Path, registry: dict[str, Any]) -> dict[str, Any]:
    """Re-scan and report changed/missing/new files against a stored registry."""
    verify(registry, REGISTRY_MODE)
    fresh = build_visible_registry(workspace, tuple(registry["scan_roots"]))
    old, new = _file_hashes(registry), _file_hashes(fresh)
    changed = sorted(p for p in old if p in new and old[p] != new[p])
    missing = sorted(p for p in old if p not in new)
    added = sorted(p for p in new if p not in old)
    return {"status": "match" if not (changed or missing or added) else "drift",
            "changed": changed, "missing": missing, "added": added}


def build_repair_inventory(workspace: Path, base_inventory: dict[str, Any],
                           registry_path: Path) -> dict[str, Any]:
    """Revalidate a previous inventory against disk and append the visible registry.

    Fail-closed: a changed/missing listed file, an incomplete or stale registry, an index that does
    not match the freeze, unequal chunk counts or an unpinned model digest all stop the build. The
    registry is read from ``registry_path`` itself so hash and content cannot refer to different
    documents. Hashes are never patched by hand.
    """
    verify(base_inventory, INVENTORY_MODE)
    root = workspace.resolve()
    registry_relative = _relative(root, registry_path)
    registry_file = _inside(root, registry_relative)
    registry = load_json(registry_file)
    verify(registry, REGISTRY_MODE)
    problems: list[str] = []
    files: list[dict[str, str]] = []
    for item in base_inventory["files"]:
        path = _inside(root, item["path"])
        if not path.is_file():
            problems.append(f"missing:{item['path']}")
        elif file_sha256(path) != item["sha256"]:
            problems.append(f"changed:{item['path']}")
        if item["path"] != registry_relative:
            files.append(dict(item))
    if problems:
        raise ManualGraphError("inventory dependencies drifted; generate new revisions first: " + ", ".join(problems))
    if not registry["complete"]:
        problems.append("visible_registry_incomplete")
    drift = verify_visible_registry(root, registry)
    if drift["status"] != "match":
        problems.append("visible_registry_stale")
    files.append({"path": registry_relative, "sha256": file_sha256(registry_file)})
    freeze = load_json(_inside(root, _path_for(base_inventory, "retrieval-corpus-freeze")))
    index = load_json(_inside(root, _path_for(base_inventory, ".index.")))
    counts = {"eligible_chunk_count": freeze["eligible_chunk_count"],
              "eligible_identity_count": len(freeze["eligible_chunk_identities"]),
              "index_record_count": len(index["records"])}
    if len(set(counts.values())) != 1:
        problems.append(f"count_mismatch:{counts}")
    if index.get("corpus_freeze_sha256") != freeze.get("content_sha256"):
        problems.append("index_corpus_freeze_mismatch")
    model = index.get("model", {})
    digest = model.get("digest")
    if model.get("model") != "bge-m3:latest" or not isinstance(digest, str) \
            or not re.fullmatch(r"[a-f0-9]{64}", digest):
        problems.append("index_model_not_pinned")
    if problems:
        raise ManualGraphError("inventory checks failed: " + "; ".join(problems))
    checks = {**counts, "index_matches_corpus_freeze": True, "index_model_digest": digest,
              "visible_registry_complete": True,
              "visible_fingerprint_count": registry["visible_fingerprint_count"]}
    inventory = {key: value for key, value in base_inventory.items()
                 if key not in {"content_sha256", "verification", "code", "files", "checks"}}
    inventory.update({"code": code_identity(), "files": files, "checks": checks,
                      "visible_registry_content_sha256": registry["content_sha256"],
                      "previous_inventory_content_sha256": base_inventory["content_sha256"]})
    return sign(inventory)


def _scan_files(root: Path, scan_roots: tuple[str, ...]) -> list[str]:
    result: list[str] = []
    for relative_root in scan_roots:
        directory = _inside(root, relative_root)
        if not directory.is_dir():
            continue
        for path in sorted(directory.glob("*.json")):
            result.append(_relative(root, path))
    return sorted(set(result))


def _inside(root: Path, relative: str) -> Path:
    resolved = (root / relative).resolve()
    if not resolved.is_relative_to(root):
        raise ManualGraphError("registry paths must stay inside the workspace")
    return resolved


def _relative(root: Path, path: Path) -> str:
    resolved = (root / path).resolve() if not path.is_absolute() else path.resolve()
    if not resolved.is_relative_to(root):
        raise ManualGraphError("registry paths must stay inside the workspace")
    return resolved.relative_to(root).as_posix()


def _classify(document: Any) -> str:
    if not isinstance(document, dict) or not isinstance(document.get("cases"), list):
        return "other"
    corpus = document.get("corpus")
    revision = corpus.get("source_revision_id") if isinstance(corpus, dict) else None
    # Strict typing keeps malformed cases in the incompatible group instead of crashing the scan.
    valid = isinstance(revision, str) and bool(revision.strip()) and all(
        isinstance(c, dict) and isinstance(c.get("question"), str) and c["question"].strip()
        and isinstance(c.get("answerability"), str)
        and isinstance(c.get("relevant_chunk_ids"), list)
        and all(isinstance(i, str) for i in c["relevant_chunk_ids"])
        and isinstance(c.get("case_id", ""), str) and isinstance(c.get("split", ""), str)
        for c in document["cases"])
    return "case_set" if valid else "incompatible_cases"


def _file_hashes(registry: dict[str, Any]) -> dict[str, str]:
    groups = ("case_sets", "dependent_artifacts", "other_json", "incompatible_case_files", "unreadable")
    return {item["path"]: item["file_sha256"] for group in groups for item in registry[group]}


def _path_for(inventory: dict[str, Any], needle: str) -> str:
    matches = [item["path"] for item in inventory["files"] if needle in item["path"]]
    if len(matches) != 1:
        raise ManualGraphError(f"inventory must list exactly one file matching {needle}")
    return matches[0]
