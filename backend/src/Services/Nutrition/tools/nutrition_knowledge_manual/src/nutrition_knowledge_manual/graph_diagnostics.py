"""Structural graph diagnostics; connectivity is not evidence of retrieval quality."""
from collections import Counter, defaultdict

from .retrieval_artifacts import sign
from .retrieval_graph import validate_candidate


def inspect_graph(candidate: dict, corpus_freeze: dict) -> dict:
    validate_candidate(candidate, corpus_freeze)
    nodes = {n["id"]: n for n in candidate["nodes"]}
    chunks = {nid for nid, n in nodes.items() if n["type"] == "chunk"}
    topics = {nid for nid, n in nodes.items() if n["type"] == "topic"}
    outgoing, neighbors = defaultdict(set), defaultdict(set)
    for edge in candidate["edges"]:
        source, target = edge["from"], edge["to"]
        outgoing[source].add(target)
        neighbors[source].add(target)
        neighbors[target].add(source)
    degrees = [len(outgoing[topic] & chunks) for topic in topics]
    pair_count, reachable_chunk_count = 0, 0
    for source in chunks:
        reachable = set()
        for middle in outgoing[source]:
            reachable.update(outgoing[middle] & chunks)
        reachable.discard(source)
        pair_count += len(reachable)
        reachable_chunk_count += bool(reachable)
    remaining, components = set(nodes), []
    while remaining:
        stack, component = [min(remaining)], set()
        while stack:
            node = stack.pop()
            if node in component:
                continue
            component.add(node)
            stack.extend(neighbors[node] - component)
        remaining -= component
        components.append(len(component & chunks))
    return sign({"schema_version": 1, "mode": "retrieval_graph_diagnostics",
        "candidate_sha256": candidate["content_sha256"],
        "corpus_freeze_sha256": corpus_freeze["content_sha256"],
        "builder": candidate.get("builder", "explicit_headings_v1"),
        "node_count": len(nodes), "edge_count": len(candidate["edges"]),
        "nodes_by_type": dict(sorted(Counter(n["type"] for n in nodes.values()).items())),
        "edges_by_type": dict(sorted(Counter(e["type"] for e in candidate["edges"]).items())),
        "edges_by_scope_basis": dict(sorted(Counter(e.get("scope_basis", "heading")
                                                    for e in candidate["edges"]).items())),
        "shared_topic_count": sum(degree > 1 for degree in degrees),
        "maximum_topic_degree": max(degrees, default=0),
        "isolated_chunk_count": sum(not neighbors[cid] for cid in chunks),
        "chunks_reaching_another_chunk_in_two_hops": reachable_chunk_count,
        "directed_two_hop_chunk_pairs": pair_count,
        "component_count": len(components), "largest_component_chunk_count": max(components, default=0),
        "release_ready": False, "scope": "candidate_structure_only"})
