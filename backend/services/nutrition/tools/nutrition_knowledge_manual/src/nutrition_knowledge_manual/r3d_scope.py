"""Metadata-only scope simulation; it does not constitute source review."""
from .errors import ManualGraphError
from .retrieval_artifacts import sign


def scoped_ids(graph, scope):
    chapters = scope.get('chapters')
    if not isinstance(chapters, list) or not chapters or any(not isinstance(c, str) for c in chapters):
        raise ManualGraphError('scope requires chapter names')
    topics = {n['id'] for n in graph['nodes'] if n['type'] == 'topic'
              and n.get('context_path') and n['context_path'][0] in chapters}
    ids = {e['from'] for e in graph['edges'] if e['type'] == 'MENTIONS' and e['to'] in topics}
    if not ids:
        raise ManualGraphError('scope has no eligible chunks')
    return ids


def restrict_graph(graph, ids):
    nodes = [n for n in graph['nodes'] if (n['type'] == 'chunk' and n['chunk_id'] in ids)
             or (n['type'] != 'chunk' and set(n['evidence_chunk_ids']) <= ids)]
    node_ids = {n['id'] for n in nodes}
    edges = [e for e in graph['edges'] if e['from'] in node_ids and e['to'] in node_ids
             and set(e['evidence_chunk_ids']) <= ids and set(e.get('scope_evidence_chunk_ids', [])) <= ids]
    return sign({**graph, 'nodes': nodes, 'edges': edges})


def scoped_cases(cases, ids):
    # No gold chunk means no evidence of scope membership. Do not manufacture
    # scoped negatives: report missing abstention coverage explicitly instead.
    return [c for c in cases if c['relevant_chunk_ids'] and set(c['relevant_chunk_ids']) <= ids]
