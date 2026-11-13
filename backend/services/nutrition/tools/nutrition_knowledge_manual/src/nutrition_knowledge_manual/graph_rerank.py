"""Experimental, seed-preserving graph retrieval. Never a release strategy."""
from __future__ import annotations

from collections import defaultdict, deque
import math
import re
import unicodedata

from .candidate_benchmark import validate_candidate_authorization
from .errors import ManualGraphError
from .retrievers import accepts, cited_hit, threshold, validate_query


def normalized_question(question):
    return ''.join(c for c in unicodedata.normalize('NFD', question.casefold())
                   if unicodedata.category(c) != 'Mn').replace('đ', 'd')


def edge_kind(edge):
    basis = edge.get('scope_basis')
    return basis if basis in {'continuation', 'outline_ancestor'} else edge['type']


def validate_parameters(parameters):
    if set(parameters) != {'support_weight', 'edge_decay', 'low_confidence_margin'}:
        raise ManualGraphError('invalid rerank parameter schema')
    threshold(parameters['support_weight'], .01, .99)
    threshold(parameters['low_confidence_margin'], 0, 1)
    if set(parameters['edge_decay']) != {'MENTIONS', 'SUPPORTED_BY', 'continuation', 'outline_ancestor'}:
        raise ManualGraphError('invalid edge decay schema')
    for value in parameters['edge_decay'].values():
        threshold(value, .01, 1)


class SeedPreservingRetriever:
    @classmethod
    def from_authorized_candidate(cls, *, seed, chunks, corpus_freeze, candidate_path,
                                  chunks_path, authorization, parameters, eligible_ids=None):
        graph = validate_candidate_authorization(authorization=authorization,
            candidate_path=candidate_path, chunks_path=chunks_path, corpus_freeze=corpus_freeze)
        if eligible_ids is not None:
            from .r3d_scope import restrict_graph
            graph = restrict_graph(graph, eligible_ids)
        return cls(seed, chunks, graph, parameters)

    def __init__(self, seed, chunks, graph, parameters):
        validate_parameters(parameters)
        self.seed, self.parameters = seed, parameters
        self.chunks = {c['chunk_id']: c for c in chunks}
        self.nodes = {n['id']: n for n in graph['nodes']}
        self.chunk_nodes = {n['chunk_id']: n['id'] for n in graph['nodes'] if n['type'] == 'chunk'}
        self.adjacency = defaultdict(list)
        self.graph_hash = graph['content_sha256']
        # Continuations of the same deepest heading are one support unit. A unit
        # casts one vote, even if twenty adjacent pages appear in the seed list.
        parent = {cid: cid for cid in self.chunks}

        def root(cid):
            while parent[cid] != cid:
                cid = parent[cid]
            return cid

        deepest = defaultdict(list)
        for edge in graph['edges']:
            self.adjacency[edge['from']].append(edge)
            if edge['type'] == 'MENTIONS':
                cid = self.nodes[edge['from']].get('chunk_id')
                if cid in self.chunks:
                    deepest[cid].append(edge)
        units = defaultdict(list)
        for cid, edges in deepest.items():
            depth = max(len(self.nodes[e['to']].get('context_path', [])) for e in edges)
            for edge in edges:
                if len(self.nodes[edge['to']].get('context_path', [])) == depth:
                    units[edge['to']].append((cid, edge.get('scope_basis')))
        for rows in units.values():
            if any(basis == 'continuation' for _, basis in rows):
                anchor = min(cid for cid, _ in rows)
                for cid, _ in rows:
                    parent[root(cid)] = root(anchor)
        self.unit = {cid: root(cid) for cid in parent}
        for edges in self.adjacency.values():
            edges.sort(key=lambda e: e['id'])

    def search(self, question, top_k=5, filters=None):
        filters = validate_query(question, top_k, filters)
        seeds = self.seed.search(question, 20, filters)
        if not seeds:
            return []
        q = normalized_question(question)
        relational = bool(re.search(r'\b(so sanh|khac nhau|lien quan|ket hop|moi quan he|vi sao|tai sao)\b', q))
        numeric = bool(re.search(r'\b(bao nhieu|nhu cau|gam|gram|kcal|ty le|ti le|phan tram)\b|\d', q))
        margin = ((seeds[0]['score'] - seeds[1]['score']) / max(abs(seeds[0]['score']), 1e-12)
                  if len(seeds) > 1 else 1)
        enabled = relational or (not numeric and margin < self.parameters['low_confidence_margin'])
        support = defaultdict(dict)
        if enabled:
            # Bounded traversal per seed; strongest path per independent support unit.
            for rank, hit in enumerate(seeds, 1):
                origin = hit['chunk_id']
                node_id = self.chunk_nodes.get(origin)
                if node_id is None:
                    continue
                queue = deque([(node_id, (), (), 1 / (60 + rank), (node_id,))])
                visited, edge_visits = {node_id}, 0
                while queue and edge_visits < 500:
                    node_id, path, kinds, value, ancestors = queue.popleft()
                    if len(path) == 2:
                        continue
                    degree = len(self.adjacency[node_id]) if self.nodes[node_id]['type'] != 'chunk' else 1
                    for edge in self.adjacency[node_id]:
                        if edge_visits >= 500:
                            break
                        edge_visits += 1
                        target = edge['to']
                        if target in ancestors or (target not in visited and len(visited) >= 200):
                            continue
                        node = self.nodes[target]
                        cid = node.get('chunk_id')
                        if cid is not None and (cid not in self.chunks or not accepts(self.chunks[cid], filters)):
                            continue
                        kind = edge_kind(edge)
                        contribution = value * self.parameters['edge_decay'][kind] / math.sqrt(max(1, degree))
                        next_path, next_kinds = path + (edge['id'],), kinds + (kind,)
                        if cid is not None and self.unit[cid] != self.unit[origin]:
                            unit = self.unit[origin]
                            old = support[cid].get(unit)
                            if old is None or contribution > old['contribution']:
                                support[cid][unit] = {'seed_chunk_id': origin, 'edge_path': list(next_path),
                                    'edge_types': list(next_kinds), 'contribution': contribution}
                        visited.add(target)
                        queue.append((target, next_path, next_kinds, contribution, ancestors + (target,)))
        seed_ids = [h['chunk_id'] for h in seeds]
        seed_rank = {cid: rank for rank, cid in enumerate(seed_ids, 1)}
        base_top = set(seed_ids[:top_k])
        # Keep seed order as a subsequence. Only genuinely new top-k entries with
        # two independent seeds may compete, and the first seed is pinned.
        expansion = [cid for cid, paths in support.items() if cid not in base_top and len(paths) >= 2]
        support_order = sorted(expansion, key=lambda cid: (
            -self.parameters['support_weight'] * sum(p['contribution'] for p in support[cid].values()), cid))
        # Conservative insertion budget: weight < 1 reserves only a fraction of
        # non-top1 slots. Base top-k seeds remain an ordered subsequence.
        budget = min(len(support_order), math.floor(self.parameters['support_weight'] * (top_k - 1)))
        admitted = support_order[:budget]
        prefix_count = max(1, top_k - budget)
        ordered = seed_ids[:prefix_count] + admitted + [cid for cid in seed_ids[prefix_count:] if cid not in admitted]
        return [cited_hit(self.chunks[cid], 1 / (60 + rank), 'graph-candidate', {
            'method': 'seed_preserving', 'graph_sha256': self.graph_hash, 'seed_rank': seed_rank.get(cid),
            'intent_gate_open': enabled, 'support_paths': list(support[cid].values()),
            'edge_path': next(iter(support[cid].values()))['edge_path'] if support[cid] else []})
            for rank, cid in enumerate(ordered[:top_k], 1)]
