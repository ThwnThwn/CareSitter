"""R3d safety and ranking tests use synthetic data only."""
from copy import deepcopy
from pathlib import Path
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

import test_candidate_benchmark as candidate_fixtures
from nutrition_knowledge_manual.errors import ManualGraphError
from nutrition_knowledge_manual.graph_explanation import explanation_index
from nutrition_knowledge_manual.graph_rerank import SeedPreservingRetriever, validate_parameters
from nutrition_knowledge_manual.jsonio import content_sha256
from nutrition_knowledge_manual.r3d_experiment import candidate_report, comparison, selection_key, validate_grid
from nutrition_knowledge_manual.r3d_scope import scoped_cases, scoped_ids, restrict_graph
from nutrition_knowledge_manual.r3d_split import (create_seal, partition_cases, reserve_dev_run, split_cases, validate_seal)
from nutrition_knowledge_manual.retrieval_artifacts import sign, write_once_atomic
from nutrition_knowledge_manual.retrieval_graph import empty_graph_review, materialize_graph
from nutrition_knowledge_manual.retrieval_release import (validate_report, freeze_benchmark, release_manifest,
    seal_for_benchmark, consume_holdout, validate_benchmark_freeze)
from nutrition_knowledge_manual.retrievers import cited_hit
from nutrition_knowledge_manual.review_policy import metadata
from nutrition_knowledge_manual.r3d_questions import import_questions
from nutrition_knowledge_manual.jsonio import write_json


class SplitTests(unittest.TestCase):
    def setUp(self):
        self.cases = {'cases': [{'case_id': f'c{i}', 'question': f'q{i}', 'split': 'development',
            'tags': ['multi_hop'] if i < 8 else ['numbers_units'] if i < 16 else ['section_locator', f'risk{i}'],
            'answerability': 'answerable' if i < 46 else 'insufficient_evidence'} for i in range(54)]}
        self.grid = {'seed': 20261110}
        self.seal = create_seal(self.cases, self.grid, {'a': 'b'})

    def test_repeatable_disjoint_stratified_split_and_no_holdout(self):
        a = split_cases(self.cases['cases'])
        self.assertEqual(a, split_cases(list(reversed(self.cases['cases']))))
        self.assertEqual(19, len(a['dev_eval']))
        self.assertEqual(3, sum(int(cid[1:]) < 8 for cid in a['dev_eval']))
        self.assertEqual(3, sum(int(cid[1:]) >= 46 for cid in a['dev_eval']))
        self.assertFalse(set(a['tuning']) & set(a['dev_eval']))
        bad = deepcopy(self.cases['cases']); bad[0]['split'] = 'holdout'
        with self.assertRaises(ManualGraphError):
            split_cases(bad)

    def test_partition_enforces_seal_and_requested_ids(self):
        partition_cases(self.seal, self.cases, 'tuning')
        with self.assertRaises(ManualGraphError):
            partition_cases(self.seal, self.cases, 'tuning', [self.seal['dev_eval'][0]])
        with self.assertRaises(ManualGraphError):
            validate_seal(self.seal, self.cases, self.grid, {'a': 'changed'})
        tampered = {**self.seal, 'dev_eval': []}
        with self.assertRaises(ManualGraphError):
            partition_cases(tampered, self.cases, 'tuning')

    def test_write_once_and_consumption_before_inference(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); seal_path = root / 'seal.json'
            write_once_atomic(seal_path, self.seal)
            with self.assertRaises(ManualGraphError):
                write_once_atomic(seal_path, self.seal)
            frozen = sign({'config_sha256': 'config'})
            reserve_dev_run(seal_path, frozen, root / 'dev1.json')
            with self.assertRaises(ManualGraphError):
                reserve_dev_run(seal_path, frozen, root / 'dev2.json')
            reserve_dev_run(seal_path, frozen, root / 'dev2.json', 'synthetic retry')
            with self.assertRaises(ManualGraphError):
                reserve_dev_run(seal_path, sign({'config_sha256': 'different'}), root / 'dev3.json', 'reason')

    def test_selection_is_wins_then_regressions_then_latency(self):
        entries = [{'id': str(i), 'scope_comparison': {'multihop_wins': w, 'singlehop_regressions': r},
                    'scope_p95_ms': p} for i, (w, r, p) in enumerate([(1, 0, 10), (2, 1, 9), (2, 0, 20), (2, 0, 19)])]
        self.assertEqual('3', min(entries, key=selection_key)['id'])


class RerankTests(unittest.TestCase):
    def setUp(self):
        self.chunks = [{'chunk_id': c, 'source_revision_id': 'synthetic', 'pdf_page': i,
                        'printed_page': i, 'source_locator': f'page:{i}'} for i, c in enumerate('abcdefxyz', 1)]
        self.nodes = [{'id': c['chunk_id'], 'type': 'chunk', 'chunk_id': c['chunk_id'],
                       'evidence_chunk_ids': [c['chunk_id']]} for c in self.chunks]
        self.nodes.append({'id': 't', 'type': 'topic', 'context_path': ['Synthetic'], 'evidence_chunk_ids': ['a', 'b', 'x']})
        self.edges = [{'id': f'e{i}', 'from': src, 'to': dst, 'type': kind, 'scope_basis': 'heading',
                       'evidence_chunk_ids': ['a']} for i, (src, dst, kind) in enumerate([
                           ('a', 't', 'MENTIONS'), ('b', 't', 'MENTIONS'), ('t', 'x', 'SUPPORTED_BY')])]
        self.params = {'support_weight': .5, 'low_confidence_margin': .1,
            'edge_decay': {'MENTIONS': .8, 'SUPPORTED_BY': .7, 'continuation': .5, 'outline_ancestor': .3}}

    def retriever(self, seed_ids='abcdef', edges=None):
        chunks = {c['chunk_id']: c for c in self.chunks}

        class Seed:
            def search(inner, question, top_k=5, filters=None):
                return [cited_hit(chunks[c], 1 / (60 + i), 'hybrid', {}) for i, c in enumerate(seed_ids, 1)][:top_k]

        return SeedPreservingRetriever(Seed(), self.chunks, sign({'nodes': self.nodes,
            'edges': self.edges if edges is None else edges}), self.params)

    def test_pin_top1_and_require_two_independent_supporters(self):
        hits = self.retriever().search('so sánh quan hệ', 5)
        self.assertEqual('a', hits[0]['chunk_id'])
        self.assertIn('x', [h['chunk_id'] for h in hits])
        paths = next(h for h in hits if h['chunk_id'] == 'x')['provenance']['support_paths']
        self.assertEqual({'a', 'b'}, {p['seed_chunk_id'] for p in paths})
        one = self.retriever(seed_ids='acdef').search('so sánh quan hệ', 5)
        self.assertNotIn('x', [h['chunk_id'] for h in one])
        remaining = [h['chunk_id'] for h in hits if h['chunk_id'] in 'abcdef']
        self.assertEqual(sorted(remaining), remaining)

    def test_numeric_and_confident_queries_preserve_seed_order(self):
        for question in ['nhu cầu bao nhiêu kcal', '123 gram']:
            hits = self.retriever().search(question)
            self.assertEqual(list('abcde'), [h['chunk_id'] for h in hits])
            self.assertFalse(hits[0]['provenance']['intent_gate_open'])
        self.params['low_confidence_margin'] = 0
        self.assertEqual(list('abcde'), [h['chunk_id'] for h in self.retriever().search('ordinary')])

    def test_continuation_votes_are_collapsed(self):
        edges = deepcopy(self.edges); edges[1]['scope_basis'] = 'continuation'
        hits = self.retriever(edges=edges).search('so sánh quan hệ')
        self.assertNotIn('x', [h['chunk_id'] for h in hits])

    def test_parameter_bounds_and_no_scope_leak(self):
        bad = deepcopy(self.params); bad['support_weight'] = 1
        with self.assertRaises(ManualGraphError):
            validate_parameters(bad)
        graph = sign({'nodes': self.nodes, 'edges': self.edges})
        ids = scoped_ids(graph, {'chapters': ['Synthetic']})
        self.assertEqual({'a', 'b'}, ids)
        view = restrict_graph(graph, ids)
        self.assertTrue(all(n.get('chunk_id') in ids for n in view['nodes']))
        self.assertEqual([{'relevant_chunk_ids': ['a']}], scoped_cases([
            {'relevant_chunk_ids': ['a']}, {'relevant_chunk_ids': ['a', 'z']}, {'relevant_chunk_ids': []}], ids))

    def test_human_import_checks_authorship_pages_count_and_duplicates(self):
        graph = sign({'nodes': self.nodes, 'edges': self.edges})
        rows = [{'case_id': f'h{i}', 'question': f'Synthetic authored comparison {i}',
                 'gold_pages': '1;2', 'chapter': 'Synthetic', 'author_id': 'human-fixture',
                 'author_is_developer': 'false'} for i in range(10)]
        scope = {'chapters': ['Synthetic']}
        result = import_questions(rows, {'cases': []}, self.chunks, graph, scope, ['developer-fixture'])
        self.assertEqual(10, len(result['cases']))
        for key, value in [('author_is_developer', 'true'), ('author_id', 'developer-fixture'),
                           ('gold_pages', '1;999'), ('chapter', 'Other')]:
            bad = deepcopy(rows); bad[0][key] = value
            with self.assertRaises(ManualGraphError):
                import_questions(bad, {'cases': []}, self.chunks, graph, scope, ['developer-fixture'])
        with self.assertRaises(ManualGraphError):
            import_questions(rows[:9], {'cases': []}, self.chunks, graph, scope, ['developer-fixture'])
        bad = deepcopy(rows); bad[0]['question'] = bad[1]['question']
        with self.assertRaises(ManualGraphError):
            import_questions(bad, {'cases': []}, self.chunks, graph, scope, ['developer-fixture'])


class ArtifactBoundaryTests(unittest.TestCase):
    def setUp(self):
        candidate_fixtures.CandidateBenchmarkTests.setUp(self)
    def test_r3d_report_cannot_enter_release_freeze_or_holdout(self):
        report = candidate_report({'candidate_demo_authorization_sha256': 'fixture'}, {'content_sha256': 'seal'},
                                 'dev_eval', {}, {'scopes': {}})
        with self.assertRaisesRegex(ManualGraphError, 'technical only'):
            validate_report(report, {}, [], {})
        with self.assertRaisesRegex(ManualGraphError, 'technical only'):
            freeze_benchmark(report=report, cases=self.fixture.cases(), chunks=self.chunks, bindings={}, corpus_freeze=self.freeze, ledger={}, developers=[], visible_evaluations=[])
        with self.assertRaisesRegex(ManualGraphError, 'technical only'):
            release_manifest(workspace=self.root, visible_report=report, visible_cases={}, visible_ledger={}, corpus_freeze={}, chunks=[], bindings={})
        with self.assertRaisesRegex(ManualGraphError, 'technical only'):
            validate_benchmark_freeze(report, {})
        with self.assertRaisesRegex(ManualGraphError, 'technical only'):
            seal_for_benchmark({}, {}, [], sign({**report, **metadata()}))
        with self.assertRaisesRegex(ManualGraphError, 'technical only'):
            consume_holdout(workspace=self.root, submission={}, marker={}, freeze=report, corpus_freeze={}, ledger={}, chunks=[], retrievers={}, bindings={})

    def test_explanation_rejects_candidate_and_tampered_graph(self):
        ledger = empty_graph_review(self.candidate, self.freeze)
        graph = materialize_graph(self.candidate, self.freeze, ledger)
        kwargs = {'candidate': self.candidate, 'ledger': ledger, 'corpus_freeze': self.freeze,
                  'chunks_path': self.fixture.chunks_path}
        with self.assertRaises(ManualGraphError):
            explanation_index(graph=self.candidate, **kwargs)
        result = explanation_index(graph=graph, **kwargs)
        self.assertEqual({}, result['chunks'])
        self.assertEqual(graph['content_sha256'], result['bindings']['graph_sha256'])
        with self.assertRaises(ManualGraphError):
            explanation_index(graph=sign({**graph, 'nodes': self.candidate['nodes']}), **kwargs)

    def test_new_factory_always_checks_candidate_authorization(self):
        with self.assertRaises(ManualGraphError):
            SeedPreservingRetriever.from_authorized_candidate(seed=None, chunks=self.chunks,
                corpus_freeze=self.freeze, candidate_path=self.path, chunks_path=self.fixture.chunks_path,
                authorization={}, parameters={})

    def test_reviewed_explanation_contains_only_metadata(self):
        from test_reviewed_graph_retrieval import approve_graph
        ledger = approve_graph(self.candidate, self.freeze)
        graph = materialize_graph(self.candidate, self.freeze, ledger)
        result = explanation_index(graph=graph, candidate=self.candidate, ledger=ledger,
                                  corpus_freeze=self.freeze, chunks_path=self.fixture.chunks_path)
        self.assertEqual({c['chunk_id'] for c in self.chunks}, set(result['chunks']))
        for entry in result['chunks'].values():
            self.assertTrue(entry['graphPath'])
            self.assertTrue(all(set(n) == {'node_id', 'heading', 'pages'} for n in entry['graphPath']))
        self.assertEqual(sign(result), result)

    def test_scope_suites_validate_full_index_then_filter_every_strategy(self):
        from nutrition_knowledge_manual.r3d_experiment import build_suites
        topic = next(n for n in self.candidate['nodes'] if n['type'] == 'topic')
        scope_path = self.root / 'scope.json'; index_path = self.root / 'index.json'
        write_json(scope_path, {'chapters': [topic['context_path'][0]]})
        write_json(index_path, self.index)
        args = SimpleNamespace(index=index_path, endpoint='http://127.0.0.1:11434',
            chunks=self.fixture.chunks_path, candidate=self.path, scope=scope_path)
        with patch('nutrition_knowledge_manual.r3d_experiment.OllamaEncoder', return_value=self.encoder):
            suites = build_suites(args, self.freeze, self.config, self.candidate, self.auth)
        for name, (chunks, retrievers, graph, ids) in suites.items():
            allowed = {c['chunk_id'] for c in chunks}
            for retriever in retrievers.values():
                self.assertTrue({h['chunk_id'] for h in retriever.search('fixture')} <= allowed)

    def test_empty_scoped_dev_is_reported_without_invented_gate_or_latency(self):
        from nutrition_knowledge_manual.r3d_experiment import run_matrix
        chunks, retrievers, bindings = candidate_fixtures.CandidateBenchmarkTests.suite(self)
        graph = retrievers.pop('graph-candidate')
        retrievers['seed_support_rrf_v2'] = graph
        base_case = self.fixture.cases()['cases'][0]
        cases = {'cases': [{**base_case, 'case_id': f'case{i}', 'question': f'Synthetic question {i}',
                            'tags': [], 'answerability': 'answerable'} for i in range(6)]}
        variant = {'id': 'synthetic', 'parameters': {'support_weight': .5, 'low_confidence_margin': .03,
            'edge_decay': {'MENTIONS': .8, 'SUPPORTED_BY': .7, 'continuation': .5, 'outline_ancestor': .3}}}
        grid = {'seed': 20261110, 'variants': [variant]}
        seal = create_seal(cases, grid, bindings)
        frozen = {'variant': variant, 'config_sha256': 'synthetic'}
        class Empty:
            def search(self, *args):
                return []
        args = SimpleNamespace(rerun_reason=None, output=self.root / 'output.json',
            candidate=self.path, chunks=self.fixture.chunks_path)
        suites = {'whole_book': (chunks, retrievers, self.candidate, None),
                  'scope_simulated': ([], {n: Empty() for n in retrievers}, self.candidate, set())}
        with patch('nutrition_knowledge_manual.r3d_experiment.build_suites', return_value=suites):
            result = run_matrix(args, 'dev_eval', cases, seal, grid, self.freeze, self.config,
                                self.candidate, self.auth, bindings, frozen)
        scoped = result['scopes']['scope_simulated']
        self.assertEqual('not_evaluable_no_eligible_cases', scoped['graph_gate_status'])
        self.assertIsNone(scoped['graph_gate_failures'])
        self.assertIsNone(scoped['strategies']['synthetic']['metrics']['latency_p95_ms'])
