"""Separate local entry point: seal -> tuning grid -> frozen dev evaluation."""
from __future__ import annotations

import argparse
from copy import copy
from pathlib import Path
import sys

from .candidate_benchmark import (CANDIDATE_MODE, CANDIDATE_REVIEW_STATUS,
                                  validate_candidate_authorization)
from .errors import ManualGraphError
from .graph_retriever import GraphRetriever
from .graph_rerank import SeedPreservingRetriever, validate_parameters, edge_kind
from .jsonio import content_sha256, file_sha256, load_json
from .ollama_encoder import OllamaEncoder
from .r3d_scope import restrict_graph, scoped_cases, scoped_ids
from .r3d_split import (create_seal, partition_cases, reserve_dev_run, validate_seal)
from .retrieval_artifacts import code_identity, local_path, sign, verify, write_once_atomic
from .retrieval_benchmark import evaluate_strategy, validate_cases
from .retrieval_release import graph_gate
from .retrieval_suite import create_suite
from .retrievers import HybridRetriever, KeywordRetriever
from .source_edition_guard import SourceEditionGuard

RULE = ['scope_multihop_wins_desc', 'scope_singlehop_regressions_asc', 'scope_p95_asc', 'config_id_asc']


def validate_grid(grid):
    if (grid.get('schema_version') != 1 or grid.get('seed') != 20261110
            or grid.get('selection_rule') != RULE or not isinstance(grid.get('variants'), list)
            or not 1 <= len(grid['variants']) <= 16):
        raise ManualGraphError('invalid predeclared grid')
    seen = set()
    for variant in grid['variants']:
        if set(variant) != {'id', 'parameters'} or not isinstance(variant['id'], str) or variant['id'] in seen:
            raise ManualGraphError('invalid/duplicate variant')
        seen.add(variant['id'])
        validate_parameters(variant['parameters'])


def comparison(graph, hybrid):
    paired = {r['case_id']: r for r in graph['results']}

    def recall(row):
        gold = set(row['relevant_chunk_ids'])
        return len(gold & {h['chunk_id'] for h in row['hits']}) / len(gold) if gold else 0

    return {'multihop_wins': sum('multi_hop' in r['tags'] and recall(paired[r['case_id']]) > recall(r)
                                  for r in hybrid['results']),
            'singlehop_regressions': sum(r['answerability'] == 'answerable' and 'multi_hop' not in r['tags']
                and recall(paired[r['case_id']]) < recall(r) for r in hybrid['results'])}


def selection_key(entry):
    scope = entry['scope_comparison']
    return (-scope['multihop_wins'], scope['singlehop_regressions'], entry['scope_p95_ms'], entry['id'])


def counts(cases):
    return {'case_count': len(cases), 'multihop_count': sum('multi_hop' in c['tags'] for c in cases),
            'answerable_count': sum(c['answerability'] == 'answerable' for c in cases),
            'insufficient_count': sum(c['answerability'] == 'insufficient_evidence' for c in cases),
            'by_tag': {t: sum(t in c['tags'] for c in cases) for t in sorted({t for c in cases for t in c['tags']})}}


def diagnostics(entry, graph):
    edges = {e['id']: e for e in graph['edges']}
    for row in entry['results']:
        row['gold_ranks'] = {cid: next((i for i, h in enumerate(row['hits'], 1) if h['chunk_id'] == cid), None)
                             for cid in row['relevant_chunk_ids']}
        paths = [p for h in row['hits'] for p in h.get('provenance', {}).get('support_paths', [])]
        row['graph_paths'] = [{'seed_chunk_id': p['seed_chunk_id'], 'length': len(p['edge_path']),
            'edge_types': [edges[e]['type'] for e in p['edge_path']],
            'scope_types': [edge_kind(edges[e]) for e in p['edge_path']]} for p in paths]
    return entry


def build_suites(args, freeze, config, candidate, authorization):
    index = load_json(args.index)
    encoder = OllamaEncoder(args.endpoint, index['model']['digest'])
    chunks, base, _ = create_suite(chunks_path=args.chunks, corpus_freeze=freeze,
                                    config=config, encoder=encoder, index=index)
    ids = scoped_ids(candidate, load_json(args.scope))
    full_graph = GraphRetriever.from_authorized_candidate(seed=base['hybrid'], chunks=chunks,
        corpus_freeze=freeze, candidate_path=args.candidate, chunks_path=args.chunks,
        authorization=authorization, hops=config['graph_hops'], max_nodes=config['graph_max_nodes'],
        max_edges=config['graph_max_edges'], rrf_k=config['rrf_k'],
        support_weight=config['graph_support_weight'], hop_decay=config['graph_hop_decay'])
    scoped_chunks = [c for c in chunks if c['chunk_id'] in ids]
    # Validate the complete index first. Copy only the vector view, never create
    # a fake scoped corpus freeze or re-sign a partially validated index.
    vector = copy(base['vector']._retriever)
    vector._chunks = {cid: c for cid, c in vector._chunks.items() if cid in ids}
    vector._vectors = {cid: v for cid, v in vector._vectors.items() if cid in ids}
    keyword = KeywordRetriever(scoped_chunks, config['keyword_minimum_score'])
    hybrid = HybridRetriever(keyword, vector, config['rrf_k'], config['fusion_candidates'])
    restricted = restrict_graph(candidate, ids)
    scoped_graph = GraphRetriever.__new__(GraphRetriever)
    # The original candidate was authorized above, and this view can only remove
    # nodes/edges. This is a simulation, never a reviewed materialization.
    scoped_graph._initialize(hybrid, scoped_chunks, restricted, hops=config['graph_hops'],
        max_nodes=config['graph_max_nodes'], max_edges=config['graph_max_edges'], rrf_k=config['rrf_k'],
        support_weight=config['graph_support_weight'], hop_decay=config['graph_hop_decay'])
    guard = lambda r: SourceEditionGuard(r, freeze['source_revision_id'])
    return {'whole_book': (chunks, {**base, 'seed_support_rrf_v2': guard(full_graph)}, candidate, None),
            'scope_simulated': (scoped_chunks, {'keyword': guard(keyword), 'vector': guard(vector),
                'hybrid': guard(hybrid), 'seed_support_rrf_v2': guard(scoped_graph)}, restricted, ids)}


def run_matrix(args, phase, cases, seal, grid, freeze, config, candidate, auth, bindings, frozen=None):
    selected_cases = partition_cases(seal, cases, phase)
    suites = build_suites(args, freeze, config, candidate, auth)
    reports, trials = {}, []
    variants = grid['variants'] if phase == 'tuning' else [frozen['variant']]
    start_code = code_identity()
    for scope_name, (chunks, retrievers, graph, ids) in suites.items():
        eligible_cases = selected_cases if ids is None else scoped_cases(selected_cases, ids)
        if eligible_cases:
            validate_cases(eligible_cases, chunks, {'development', 'validation'})
        reports[scope_name] = {'counts': counts(eligible_cases), 'chunk_count': len(chunks),
            'coverage_note': 'scope excludes cases without scoped gold chunks' if ids is not None else None,
            'strategies': {}}
        strategies = reports[scope_name]['strategies']
        for name, retriever in retrievers.items():
            strategies[name] = diagnostics(evaluate_strategy(retriever, eligible_cases, chunks), graph)
        for variant in variants:
            retriever = SeedPreservingRetriever.from_authorized_candidate(seed=retrievers['hybrid'],
                chunks=chunks, corpus_freeze=freeze, candidate_path=args.candidate,
                chunks_path=args.chunks, authorization=auth, parameters=variant['parameters'], eligible_ids=ids)
            entry = diagnostics(evaluate_strategy(retriever, eligible_cases, chunks), graph)
            strategies[variant['id']] = entry
            if phase == 'tuning':
                trial = candidate_report(bindings, seal, phase, start_code, {
                    'config_id': variant['id'], 'config_sha256': content_sha256(variant),
                    'scope': scope_name, 'measurement': entry,
                    'comparison': comparison(entry, strategies['hybrid'])})
                write_once_atomic(args.output.with_name(args.output.stem + '.' + scope_name + '.' + variant['id'] + '.json'), trial)
        if phase == 'dev_eval':
            best = strategies[frozen['variant']['id']]
            reports[scope_name]['graph_gate_status'] = 'evaluated' if eligible_cases else 'not_evaluable_no_eligible_cases'
            reports[scope_name]['graph_gate_failures'] = graph_gate(best, strategies['hybrid']) if eligible_cases else None
            reports[scope_name]['comparison'] = comparison(best, strategies['hybrid'])
    if phase == 'tuning':
        for variant in variants:
            scope = reports['scope_simulated']['strategies']
            whole = reports['whole_book']['strategies']
            trials.append({'id': variant['id'], 'config_sha256': content_sha256(variant),
                'scope_comparison': comparison(scope[variant['id']], scope['hybrid']),
                'whole_book_comparison': comparison(whole[variant['id']], whole['hybrid']),
                'scope_p95_ms': scope[variant['id']]['metrics']['latency_p95_ms']})
    end_code = code_identity()
    # R2b may change unrelated modules concurrently. Record both snapshots and
    # require the actual retrieval/experiment dependencies to stay unchanged.
    dependencies = ['r3d_experiment.py', 'r3d_split.py', 'r3d_scope.py', 'graph_rerank.py',
        'graph_retriever.py', 'candidate_benchmark.py', 'retrievers.py', 'source_edition_guard.py',
        'keyword_retriever.py', 'embedding_index.py', 'ollama_encoder.py', 'retrieval_benchmark.py']
    if any(start_code['files'][n] != end_code['files'][n] for n in dependencies):
        raise ManualGraphError('experiment dependency changed during evaluation')
    return candidate_report(bindings, seal, phase, start_code, {
        'scopes': reports, 'trials': trials, 'code_after': end_code,
        'frozen_config_sha256': frozen['config_sha256'] if frozen else None,
        'rerun_reason': args.rerun_reason})


def candidate_report(bindings, seal, phase, code, extra):
    return sign({'schema_version': 1, 'mode': CANDIDATE_MODE, 'review_status': CANDIDATE_REVIEW_STATUS,
        'release_ready': False, 'dataset_kind': 'visible', 'phase': phase, 'bindings': bindings,
        'split_seal_sha256': seal['content_sha256'], 'code': code, **extra})


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=['seal', 'tuning', 'dev_eval'])
    parser.add_argument('--workspace', type=Path, default=Path('.'))
    for name in ['chunks', 'corpus-freeze', 'cases', 'config', 'grid', 'index', 'candidate', 'authorization', 'scope', 'seal', 'output']:
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--frozen', type=Path)
    parser.add_argument('--endpoint', default='http://127.0.0.1:11434')
    parser.add_argument('--rerun-reason')
    args = parser.parse_args(argv)
    try:
        args.workspace = args.workspace.resolve()
        for name in ['chunks', 'corpus_freeze', 'cases', 'index', 'candidate', 'authorization', 'seal', 'output', 'frozen']:
            if getattr(args, name) is not None:
                setattr(args, name, local_path(args.workspace, getattr(args, name)))
        for name in ['config', 'grid', 'scope']:
            setattr(args, name, (args.workspace / getattr(args, name)).resolve())
        artifact_root = args.workspace / 'backend/artifacts/nutrition-knowledge-local'
        if (not args.seal.is_relative_to(artifact_root / 'evaluation')
                or not args.output.is_relative_to(artifact_root / 'reports')):
            raise ManualGraphError('R3d seal must be in evaluation and output in reports')
        if args.output.exists():
            raise ManualGraphError('output exists; use a new path')
        cases, grid, freeze, config, auth = [load_json(p) for p in
            [args.cases, args.grid, args.corpus_freeze, args.config, args.authorization]]
        validate_grid(grid)
        candidate = validate_candidate_authorization(authorization=auth, candidate_path=args.candidate,
            chunks_path=args.chunks, corpus_freeze=freeze)
        bindings = {'candidate_demo_authorization_sha256': auth['content_sha256'],
            'graph_candidate_sha256': candidate['content_sha256'],
            **{name + '_file_sha256': file_sha256(getattr(args, name)) for name in
               ['chunks', 'corpus_freeze', 'cases', 'config', 'grid', 'index', 'candidate', 'authorization', 'scope']}}
        if args.phase == 'seal':
            seal = create_seal(cases, grid, bindings)
            write_once_atomic(args.seal, seal)
            print('sealed', seal['content_sha256'], 'dev IDs', seal['dev_eval_ids_sha256'],
                  'tuning', len(seal['tuning']), 'dev_eval', len(seal['dev_eval']))
            return 0
        seal = load_json(args.seal)
        validate_seal(seal, cases, grid, bindings)
        frozen_path = args.seal.with_name(args.seal.stem + '.frozen.json')
        if args.phase == 'tuning':
            if frozen_path.exists() or args.seal.with_name(args.seal.stem + '.dev-consumed.json').exists():
                raise ManualGraphError('experiment already frozen; tuning forbidden')
            # Persist the exact declared grid before the first tuning inference.
            write_once_atomic(args.seal.with_name(args.seal.stem + '.tuning-start.json'),
                candidate_report(bindings, seal, 'tuning', code_identity(), {'grid': grid}))
            report = run_matrix(args, args.phase, cases, seal, grid, freeze, config, candidate, auth, bindings)
            write_once_atomic(args.output, report)
            winner = min(report['trials'], key=selection_key)
            variant = next(v for v in grid['variants'] if v['id'] == winner['id'])
            frozen = sign({'schema_version': 1, 'mode': 'r3d_frozen_configuration',
                'split_seal_sha256': seal['content_sha256'], 'tuning_report_sha256': report['content_sha256'],
                'variant': variant, 'config_sha256': content_sha256({'base': config, 'variant': variant}),
                'bindings': bindings, 'selection_rule': RULE, 'selection': winner,
                'code': report['code_after']})
            write_once_atomic(frozen_path, frozen)
            print('selected', winner['id'], 'frozen', frozen['content_sha256'])
        else:
            if args.frozen is None or args.frozen != frozen_path:
                raise ManualGraphError('dev_eval requires the canonical frozen config')
            frozen = load_json(args.frozen)
            verify(frozen, 'r3d_frozen_configuration')
            if (frozen['split_seal_sha256'] != seal['content_sha256'] or frozen['bindings'] != bindings
                    or frozen['config_sha256'] != content_sha256({'base': config, 'variant': frozen['variant']})):
                raise ManualGraphError('frozen configuration binding mismatch')
            current = code_identity()['files']
            if any(current[n] != h for n, h in frozen['code']['files'].items()
                   if n.startswith(('r3d_split', 'r3d_scope', 'graph_rerank', 'graph_retriever', 'retrievers', 'ollama_encoder',
                                    'embedding_index', 'keyword_retriever', 'source_edition_guard', 'candidate_benchmark', 'retrieval_benchmark'))):
                raise ManualGraphError('retrieval code changed after configuration freeze')
            reserve_dev_run(args.seal, frozen, args.output, args.rerun_reason)
            report = run_matrix(args, args.phase, cases, seal, grid, freeze, config, candidate, auth, bindings, frozen)
            report = sign({**report, 'tuning_code_sha256': frozen['code']['sha256'],
                'evaluation_runner_changed_since_tuning': frozen['code']['files']['r3d_experiment.py']
                    != report['code']['files']['r3d_experiment.py']})
            write_once_atomic(args.output, report)
            print('dev_eval saved', report['content_sha256'])
        return 0
    except (ManualGraphError, OSError, KeyError, ValueError):
        # Never echo input/provider text, including malformed case content.
        print('R3d refused or failed; check local artifacts, bindings and consumption markers', file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
