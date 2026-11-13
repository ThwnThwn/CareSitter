"""Validate human-authored multihop drafts locally; never author questions."""
import argparse
import csv
from pathlib import Path
import re
import sys

from .errors import ManualGraphError
from .jsonio import content_sha256, file_sha256, load_json
from .candidate_benchmark import validate_candidate_authorization
from .r3d_scope import scoped_ids
from .retrieval_artifacts import local_path, write_once_atomic
from .retrieval_benchmark import validate_cases
from .retrieval_eval import load_retrieval_chunks

FIELDS = ['case_id', 'question', 'gold_pages', 'chapter', 'author_id', 'author_is_developer']


def import_questions(rows, base, chunks, graph, scope, developers):
    if not developers or not 10 <= len(rows) <= 15:
        raise ManualGraphError('requires developer IDs and 10-15 human authored cases')
    ids = scoped_ids(graph, scope)
    by_page = {}
    for chunk in chunks:
        if chunk['chunk_id'] in ids:
            by_page.setdefault(chunk.get('pdf_page'), []).append(chunk['chunk_id'])
    added = []
    for row in rows:
        if (set(row) != set(FIELDS) or any(not isinstance(row[k], str) or not row[k].strip() for k in FIELDS)
                or row['author_is_developer'].strip().casefold() != 'false'
                or row['author_id'].strip().casefold() in {d.strip().casefold() for d in developers}
                or any(c.strip() not in scope['chapters'] for c in row['chapter'].split('|'))
                or not re.fullmatch(r'\d+(?:\s*;\s*\d+)*', row['gold_pages'])):
            raise ManualGraphError('invalid human author/fields/pages/chapter')
        pages = [int(p.strip()) for p in row['gold_pages'].split(';')]
        if len(pages) != len(set(pages)) or any(p not in by_page for p in pages):
            raise ManualGraphError('gold pages outside simulated scope or duplicated')
        relevant = sorted({cid for page in pages for cid in by_page[page]})
        # Every selected evidence chunk must belong to the declared chapter.
        chapter_ids = scoped_ids(graph, {'chapters': [c.strip() for c in row['chapter'].split('|')]})
        if len(relevant) < 2 or not set(relevant) <= chapter_ids:
            raise ManualGraphError('multihop requires two evidence chunks in the declared chapter')
        added.append({'case_id': row['case_id'].strip(), 'question': row['question'].strip(),
            'relevant_chunk_ids': relevant, 'gold_pages': pages, 'chapter': row['chapter'],
            'author_id': row['author_id'].strip(), 'author_is_developer': False,
            'answerability': 'answerable', 'tags': ['multi_hop'], 'split': 'development',
            'review_status': 'pending_human_review'})
    all_cases = [*base['cases'], *added]
    validate_cases(all_cases, chunks, {'development', 'validation'})
    return {**base, 'cases': all_cases, 'status': 'human_authored_visible_draft_not_holdout',
            'r3d_import': {'base_sha256': content_sha256(base), 'added_ids': [c['case_id'] for c in added],
                           'scope_sha256': content_sha256(scope), 'independent_authorship_is_attestation': True}}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--workspace', type=Path, default=Path('.'))
    for name in ['sheet', 'base-cases', 'chunks', 'candidate', 'authorization', 'corpus-freeze', 'output', 'scope']:
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--developer', action='append', required=True)
    args = parser.parse_args(argv)
    try:
        root = args.workspace.resolve()
        for name in ['sheet', 'base_cases', 'chunks', 'candidate', 'authorization', 'corpus_freeze', 'output']:
            setattr(args, name, local_path(root, getattr(args, name)))
        graph = validate_candidate_authorization(authorization=load_json(args.authorization),
            candidate_path=args.candidate, chunks_path=args.chunks, corpus_freeze=load_json(args.corpus_freeze))
        with args.sheet.open(encoding='utf-8-sig', newline='') as stream:
            rows = list(csv.DictReader(stream))
        result = import_questions(rows, load_json(args.base_cases), load_retrieval_chunks(args.chunks),
                                  graph, load_json(root / args.scope), args.developer)
        result['r3d_import']['sheet_sha256'] = file_sha256(args.sheet)
        write_once_atomic(args.output, result)
        print('imported human drafts', len(result['r3d_import']['added_ids']))
        return 0
    except (ManualGraphError, OSError, KeyError, ValueError):
        print('human draft import refused; check local sheet and scope', file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
