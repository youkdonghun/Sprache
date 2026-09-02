#!/usr/bin/env python3
"""Extract deterministic Korean-to-target TUFS vocabulary alignments.

The TUFS downloads are PostgreSQL custom-format dumps. Install ``pgdumplib``
and expand ``vmod_<code>.zip`` into one directory per language before running
this helper. The database dumps themselves are not committed.
"""

from __future__ import annotations

import argparse
import json
import re
import unicodedata
from dataclasses import dataclass
from pathlib import Path

import pgdumplib


LANGUAGES = ("de", "en", "es", "fr", "ja", "zh")
ALL_CODES = ("ko", *LANGUAGES)
SOURCE_URL = "https://www.coelang.tufs.ac.jp/mt/vmod/"


@dataclass(frozen=True)
class Candidate:
    term: str
    preferred: bool
    headword: str
    kana: str


def normalize(value: object) -> str:
    return re.sub(r"\s+", " ", unicodedata.normalize("NFKC", str(value or ""))).strip()


def load_candidates(dump_path: Path) -> dict[str, list[Candidate]]:
    dump = pgdumplib.load(dump_path)
    usages = {row[0]: row[1] for row in dump.table_data("public", "t_usage")}
    words = {row[0]: row for row in dump.table_data("public", "t_word")}
    result: dict[str, list[Candidate]] = {}
    for relation in dump.table_data("public", "t_usage_classified_rel"):
        word = words.get(usages.get(relation[0], ""))
        if word is None:
            continue
        term = normalize(word[1])
        concept_id = normalize(relation[1])
        if not term or not concept_id:
            continue
        result.setdefault(concept_id, []).append(
            Candidate(
                term=term,
                preferred=word[2] == "1",
                headword=normalize(relation[9]),
                kana=normalize(relation[10]),
            )
        )
    return result


def choose_candidate(values: list[Candidate]) -> Candidate:
    return sorted(
        values,
        key=lambda value: (not value.preferred, len(value.term), value.term),
    )[0]


def clean_variant_label(value: str) -> str:
    return re.sub(r"\s*\(\d+\)$", "", value).strip()


def is_kana(value: str) -> bool:
    return bool(value) and re.fullmatch(
        r"[\u3040-\u30ff\u31f0-\u31ff\u3000\sー・～〜,.!?！？]+", value
    ) is not None


def safe_japanese_reading(candidate: Candidate) -> str | None:
    term = clean_variant_label(candidate.term)
    headword = clean_variant_label(candidate.headword)
    kana = candidate.kana
    if is_kana(term):
        return term
    if not kana or not is_kana(kana):
        return None
    if term == headword:
        return kana

    common = 0
    for left, right in zip(term, headword):
        if left != right:
            break
        common += 1
    old_suffix = headword[common:]
    new_suffix = term[common:]
    if old_suffix and is_kana(old_suffix) and is_kana(new_suffix) and kana.endswith(old_suffix):
        return f"{kana[:-len(old_suffix)]}{new_suffix}"
    return None


def dump_path(root: Path, code: str) -> Path:
    candidates = (
        root / code / f"vmod_{code}.dump",
        root / f"vmod_{code}.dump",
    )
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    raise FileNotFoundError(f"vmod_{code}.dump was not found under {root}")


def build_payload(root: Path) -> dict[str, object]:
    candidates = {
        code: load_candidates(dump_path(root, code)) for code in ALL_CODES
    }
    korean = {
        concept_id: choose_candidate(values)
        for concept_id, values in candidates["ko"].items()
    }
    languages: dict[str, list[dict[str, object]]] = {}
    for code in LANGUAGES:
        rows: list[dict[str, object]] = []
        for concept_id in sorted(
            set(korean).intersection(candidates[code]), key=lambda value: int(value)
        ):
            target = choose_candidate(candidates[code][concept_id])
            row: dict[str, object] = {
                "conceptId": concept_id,
                "ko": korean[concept_id].term,
                "term": target.term,
            }
            if not target.preferred:
                row["preferred"] = False
            if code == "ja":
                reading = safe_japanese_reading(target)
                if reading:
                    row["kana"] = reading
            rows.append(row)
        languages[code] = rows

    return {
        "schemaVersion": 2,
        "source": "TUFS Open Language Resources - Basic vocabularies in 24 languages",
        "sourceUrl": SOURCE_URL,
        "license": "CC-BY-4.0",
        "citation": (
            "Kawaguchi, Yuji. 2007. Foundations of Center of Usage-Based "
            "Linguistic Informatics (UBLI)."
        ),
        "extraction": (
            "Pairwise classified_id intersection between Korean and each target "
            "module; preferred display forms first; NFKC whitespace normalization."
        ),
        "languages": languages,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-root", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    payload = build_payload(args.input_root.resolve())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    counts = {code: len(rows) for code, rows in payload["languages"].items()}
    print(json.dumps(counts, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
