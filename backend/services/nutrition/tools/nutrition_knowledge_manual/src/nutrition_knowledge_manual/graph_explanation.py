"""Export metadata paths only after validating an already materialized graph."""
from __future__ import annotations

import argparse
from pathlib import Path
import sys

from .corpus_freeze import validate_retrieval_corpus_binding
from .errors import ManualGraphError
from .jsonio import file_sha256, load_json
from .retrieval_artifacts import local_path, sign, verify, write_once_atomic
from .retrieval_eval import load_retrieval_chunks
from .retrieval_graph import materialize_graph
from .review_policy import DEFAULT, REFERENCE


def explanation_index(*, graph, candidate, ledger, corpus_freeze, chunks_path, review_policy=DEFAULT):
    verify(graph, 'reviewed_retrieval_graph')
    validate_retrieval_corpus_binding(corpus_freeze=corpus_freeze, chunks_path=chunks_path)
    # Read-only recomputation is the existing materialization validator. Never
    # modify its rules, admit pending nodes, or fabricate review evidence.
    expected = materialize_graph(candidate, corpus_freeze, ledger, review_policy)
    if graph != expected:
        raise ManualGraphError('explanation graph differs from materialized review evidence')
    nodes = {n['id']: n for n in graph['nodes']}
    chunks = {c['chunk_id']: c for c in load_retrieval_chunks(chunks_path)}
    paths = {}
    topics = {tuple(n.get('context_path', [])): n for n in nodes.values() if n['type'] == 'topic'}
    for node in nodes.values():
        if node['type'] != 'chunk':
            continue
        cid = node['chunk_id']
        mentions = [nodes[e['to']] for e in graph['edges'] if e['type'] == 'MENTIONS' and e['from'] == node['id']
                    and nodes[e['to']]['type'] == 'topic']
        topic = min(mentions, key=lambda n: (-len(n.get('context_path', [])), n['id'])) if mentions else None
        chain = []
        if topic:
            context = topic.get('context_path', [])
            for depth in range(len(context), 0, -1):
                ancestor = topics.get(tuple(context[:depth]))
                if ancestor:
                    pages = sorted({chunks[c]['pdf_page'] for c in ancestor.get('heading_chunk_ids', [])
                                    if c in chunks and isinstance(chunks[c].get('pdf_page'), int)})
                    chain.append({'node_id': ancestor['id'], 'heading': ancestor.get('heading'), 'pages': pages})
            chain.append({'node_id': node['id'], 'heading': None,
                          'pages': [chunks[cid]['pdf_page']] if isinstance(chunks[cid].get('pdf_page'), int) else []})
        paths[cid] = {'graphPath': chain}
    bindings = {'graph_sha256': graph['content_sha256'], 'candidate_sha256': candidate['content_sha256'],
        'ledger_sha256': ledger['content_sha256'], 'corpus_sha256': file_sha256(chunks_path),
        'corpus_freeze_sha256': corpus_freeze['content_sha256']}
    return sign({'schema_version': 1, 'mode': 'reviewed_graph_explanation_index', 'bindings': bindings,
                 'review_policy': review_policy, 'chunks': paths})


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--workspace', type=Path, default=Path('.'))
    for name in ['graph', 'candidate', 'ledger', 'corpus-freeze', 'chunks', 'output']:
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--review-policy', choices=[DEFAULT, REFERENCE], default=DEFAULT)
    args = parser.parse_args(argv)
    try:
        paths = {name: local_path(args.workspace.resolve(), getattr(args, name)) for name in
                 ['graph', 'candidate', 'ledger', 'corpus_freeze', 'chunks', 'output']}
        result = explanation_index(**{k: load_json(paths[k]) for k in ['graph', 'candidate', 'ledger', 'corpus_freeze']},
                                   chunks_path=paths['chunks'], review_policy=args.review_policy)
        write_once_atomic(paths['output'], result)
        print('explanation index', result['content_sha256'], 'chunks', len(result['chunks']))
        return 0
    except (ManualGraphError, OSError, KeyError, ValueError):
        print('explanation export refused: verify local reviewed graph and bindings', file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
