from __future__ import annotations

from collections import defaultdict, deque

from .errors import ManualGraphError
from .retrieval_graph import materialize_graph
from .retrievers import Retriever, accepts, cited_hit, validate_query


class GraphRetriever:
    def __init__(self, seed: Retriever, chunks: list[dict], corpus_freeze: dict,
                 candidate: dict, ledger: dict, graph: dict, hops: int = 2,
                 max_nodes: int = 200, max_edges: int = 500):
        expected = materialize_graph(candidate, corpus_freeze, ledger)
        if graph != expected:
            raise ManualGraphError("reviewed graph does not match its review evidence")
        if (any(isinstance(v, bool) or not isinstance(v, int) for v in (hops, max_nodes, max_edges))
                or not 1 <= hops <= 2 or not 1 <= max_nodes <= 1000 or not 1 <= max_edges <= 5000):
            raise ManualGraphError("graph traversal limits are invalid")
        if not graph["edges"]:
            raise ManualGraphError("graph retrieval requires reviewed edges")
        self._seed, self._hops = seed, hops
        self._max_nodes, self._max_edges = max_nodes, max_edges
        self._chunks = {c["chunk_id"]: c for c in chunks}
        self._nodes = {n["id"]: n for n in graph["nodes"]}
        self._chunk_nodes = {n["chunk_id"]: n["id"] for n in graph["nodes"] if n["type"] == "chunk"}
        self._adjacency = defaultdict(list)
        self._hash = graph["content_sha256"]
        for edge in sorted(graph["edges"], key=lambda e: e["id"]):
            self._adjacency[edge["from"]].append(edge)

    def search(self, question: str, top_k: int = 5, filters: dict | None = None) -> list[dict]:
        filters = validate_query(question, top_k, filters)
        seeds = self._seed.search(question, 20, filters)
        scores = {h["chunk_id"]: 1 / (60 + rank) for rank, h in enumerate(seeds, 1)}
        paths = {cid: [] for cid in scores}
        queue, seen = deque(), set()
        for hit in seeds:
            node_id = self._chunk_nodes.get(hit["chunk_id"])
            if node_id and node_id not in seen and len(seen) < self._max_nodes:
                seen.add(node_id)
                queue.append((node_id, [], scores[hit["chunk_id"]]))
        traversed = 0
        while queue and traversed < self._max_edges:
            node_id, path, seed_score = queue.popleft()
            if len(path) >= self._hops:
                continue
            for edge in self._adjacency[node_id]:
                if traversed >= self._max_edges:
                    break
                traversed += 1
                target = edge["to"]
                if target in seen or len(seen) >= self._max_nodes:
                    continue
                seen.add(target)
                next_path = path + [edge["id"]]
                node = self._nodes[target]
                if node["type"] == "chunk":
                    cid = node["chunk_id"]
                    if accepts(self._chunks[cid], filters):
                        scores[cid] = scores.get(cid, 0.0) + seed_score * (0.8 ** len(next_path))
                        paths[cid] = next_path
                queue.append((target, next_path, seed_score))
        return [cited_hit(self._chunks[cid], scores[cid], "graph", {"graph_sha256": self._hash,
                    "edge_path": paths[cid], "visited_nodes": len(seen), "visited_edges": traversed})
                for cid in sorted(scores, key=lambda c: (-scores[c], c))[:top_k]]
