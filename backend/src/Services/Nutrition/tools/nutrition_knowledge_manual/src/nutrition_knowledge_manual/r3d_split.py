"""Reproducible stratification and write-once experiment consumption."""
from collections import Counter, defaultdict
from pathlib import Path

from .errors import ManualGraphError
from .jsonio import content_sha256, load_json
from .retrieval_artifacts import sign, verify, write_once_atomic

SEED = 20261110
MODE = 'r3d_visible_split_seal'


def split_cases(cases, seed=SEED):
    groups = defaultdict(list)
    ids = [c['case_id'] for c in cases]
    if len(ids) != len(set(ids)) or not ids:
        raise ManualGraphError('split requires unique nonempty cases')
    for case in cases:
        if case.get('split') not in {'development', 'validation'}:
            raise ManualGraphError('R3d accepts visible cases only')
        groups[('multi_hop' in case['tags'], case['answerability'])].append(case)
    tuning, dev = [], []
    for key, rows in sorted(groups.items()):
        # Primary strata preserve hop/answerability counts; iterative rare-tag
        # allocation balances risk tags without singleton Cartesian strata.
        target = max(1, round(len(rows) / 3)) if len(rows) > 1 else 0
        totals = Counter(t for c in rows for t in c['tags'])
        selected = Counter()
        remaining = list(rows)
        for _ in range(target):
            chosen = min(remaining, key=lambda c: (
                -sum((totals[t] * target / len(rows) - selected[t]) / totals[t] for t in c['tags']),
                content_sha256([seed, key, c['case_id']])))
            dev.append(chosen['case_id'])
            selected.update(chosen['tags'])
            remaining.remove(chosen)
        tuning.extend(c['case_id'] for c in remaining)
    return {'tuning': sorted(tuning), 'dev_eval': sorted(dev)}


def create_seal(cases, grid, bindings):
    partitions = split_cases(cases['cases'], grid['seed'])
    return sign({'schema_version': 1, 'mode': MODE, 'seed': grid['seed'],
        'evaluation_sha256': content_sha256(cases), 'grid_sha256': content_sha256(grid),
        'bindings': bindings, **partitions, 'dev_eval_ids_sha256': content_sha256(partitions['dev_eval'])})


def validate_seal(seal, cases, grid, bindings):
    verify(seal, MODE)
    if seal != create_seal(cases, grid, bindings):
        raise ManualGraphError('split seal/evaluation/grid/bindings mismatch')


def partition_cases(seal, cases, phase, requested_ids=None):
    verify(seal, MODE)
    if phase not in {'tuning', 'dev_eval'}:
        raise ManualGraphError('invalid experiment phase')
    allowed = set(seal[phase])
    requested = allowed if requested_ids is None else set(requested_ids)
    if not requested or not requested <= allowed:
        raise ManualGraphError('requested cases cross sealed partition')
    if content_sha256(cases) != seal['evaluation_sha256']:
        raise ManualGraphError('evaluation changed after seal')
    return [c for c in cases['cases'] if c['case_id'] in requested]


def reserve_dev_run(seal_path: Path, frozen, output: Path, rerun_reason=None):
    """Consume before inference. A failed run stays consumed, as for holdout."""
    marker = seal_path.with_name(seal_path.stem + '.dev-consumed.json')
    body = sign({'schema_version': 1, 'mode': 'r3d_dev_consumption',
        'frozen_sha256': frozen['content_sha256'], 'config_sha256': frozen['config_sha256'],
        'output': str(output), 'rerun_reason': rerun_reason})
    if marker.exists():
        original = load_json(marker)
        verify(original, 'r3d_dev_consumption')
        if original['frozen_sha256'] != frozen['content_sha256']:
            raise ManualGraphError('dev_eval configuration is already locked')
        if not isinstance(rerun_reason, str) or not rerun_reason.strip():
            raise ManualGraphError('dev_eval already consumed; --rerun-reason required')
        write_once_atomic(output.with_suffix('.consumption.json'), body)
    else:
        write_once_atomic(marker, body)
