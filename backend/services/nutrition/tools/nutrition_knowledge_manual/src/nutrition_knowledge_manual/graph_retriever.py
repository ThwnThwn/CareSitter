from __future__ import annotations

from collections import defaultdict, deque
import math

from .errors import ManualGraphError
from .retrieval_graph import materialize_graph
from .retrievers import Retriever, accepts, cited_hit, threshold, validate_query


class GraphRetriever:
    def __init__(self, seed: Retriever, chunks: list[dict], corpus_freeze: dict,
                 candidate: dict, ledger: dict, graph: dict, hops: int = 2,
                 max_nodes: int = 200, max_edges: int = 500, rrf_k: int = 60,
                 support_weight: float = 1.0, hop_decay: float = 0.8):
        expected = materialize_graph(candidate, corpus_freeze, ledger)
        if graph != expected:
            raise ManualGraphError("reviewed graph does not match its review evidence")
        if (any(isinstance(v, bool) or not isinstance(v, int) for v in (hops, max_nodes, max_edges))
                or not 1 <= hops <= 2 or not 1 <= max_nodes <= 1000 or not 1 <= max_edges <= 5000):
            raise ManualGraphError("graph traversal limits are invalid")
        if not graph["edges"]:
            raise ManualGraphError("graph retrieval requires reviewed edges")
        if isinstance(rrf_k, bool) or not isinstance(rrf_k, int) or not 1 <= rrf_k <= 1000:
            raise ManualGraphError("invalid graph fusion bound")
        self._rrf_k = rrf_k
        self._support_weight = threshold(support_weight, 0, 2)
        self._hop_decay = threshold(hop_decay, 0.01, 1)
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
        scores, seed_ranks, support = {}, {}, defaultdict(dict)
        queue, visited, visited_edges, best = deque(), set(), set(), {}
        for rank, hit in enumerate(seeds, 1):
            cid = hit["chunk_id"]
            node_id = self._chunk_nodes.get(cid)
            if (node_id is None or node_id in visited or len(visited) >= self._max_nodes
                    or not accepts(self._chunks[cid], filters)):
                continue
            visited.add(node_id)
            seed_ranks[cid] = rank
            scores[cid] = 1 / (self._rrf_k + rank)
            best[(cid, node_id)] = scores[cid]
            queue.append((cid, node_id, (), (node_id,), scores[cid]))
        traversed = 0
        while queue and traversed < self._max_edges:
            origin, node_id, path, ancestors, value = queue.popleft()
            if len(path) >= self._hops or value < best[(origin, node_id)]:
                continue
            # Broad topics contribute less support. Keep only the strongest path per
            # seed/target so duplicate outline routes cannot manufacture agreement.
            degree = len(self._adjacency[node_id]) if self._nodes[node_id]["type"] != "chunk" else 1
            contribution = value * self._hop_decay / math.sqrt(max(1, degree))
            for edge in self._adjacency[node_id]:
                if traversed >= self._max_edges:
                    break
                traversed += 1
                visited_edges.add(edge["id"])
                target = edge["to"]
                if target in ancestors or (target not in visited and len(visited) >= self._max_nodes):
                    continue
                node = self._nodes[target]
                if node["type"] == "chunk" and not accepts(self._chunks[node["chunk_id"]], filters):
                    continue
                if contribution <= best.get((origin, target), 0):
                    continue
                best[(origin, target)] = contribution
                visited.add(target)
                next_path = path + (edge["id"],)
                if node["type"] == "chunk":
                    cid = node["chunk_id"]
                    support[cid][origin] = {"seed_chunk_id": origin, "edge_path": list(next_path),
                                            "contribution": contribution}
                queue.append((origin, target, next_path, ancestors + (target,), contribution))

        support_scores = {cid: sum(p["contribution"] for p in paths.values())
                          for cid, paths in support.items()}
        support_ranks = {}
        if self._support_weight:
            # Fuse ranks on the same scale as seed ranks. Raw decayed path scores
            # were always below the top-20 seeds, so expansion could not enter top 5.
            for rank, cid in enumerate(sorted(support_scores, key=lambda c: (-support_scores[c], c)), 1):
                support_ranks[cid] = rank
                scores[cid] = scores.get(cid, 0.0) + self._support_weight / (self._rrf_k + rank)
        paths = {cid: sorted(support[cid].values(), key=lambda p: (-p["contribution"], p["seed_chunk_id"]))
                 for cid in scores}
        return [cited_hit(self._chunks[cid], scores[cid], "graph", {
                    "graph_sha256": self._hash, "method": "seed_support_rrf_v2",
                    "rrf_k": self._rrf_k, "support_weight": self._support_weight, "hop_decay": self._hop_decay,
                    "seed_rank": seed_ranks.get(cid), "support_rank": support_ranks.get(cid),
                    "support_score": support_scores.get(cid, 0.0), "support_paths": paths[cid],
                    "edge_path": paths[cid][0]["edge_path"] if paths[cid] else [],
                    "visited_nodes": len(visited), "visited_edges": len(visited_edges), "edge_visits": traversed})
                for cid in sorted(scores, key=lambda c: (-scores[c], c))[:top_k]]
