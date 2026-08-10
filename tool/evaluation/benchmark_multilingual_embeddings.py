#!/usr/bin/env python3
"""Reproducible host-only benchmark for Wara2a multilingual embeddings.

This script never downloads a model and never treats host execution as Android
evidence. Pass a verified local Hugging Face snapshot and ONNX file explicitly.
It evaluates:

* the checked-in 50-invoice/100-query all-route contract, reported by language
  and route without using it to approve a semantic distance threshold; and
* the balanced Arabic-only, English-only, and mixed Arabic/English
  positive/no-result semantic calibration fixture, from which one provisional
  global threshold is emitted only when every language is strictly separable.

The document builder and Arabic query normalizer below mirror production Dart.
At startup they are checked against the checked-in production goldens.
"""

from __future__ import annotations

import argparse
import calendar
import hashlib
import json
import os
import platform
import re
import statistics
import time
from collections import Counter
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable

import numpy as np
import onnxruntime as ort
import psutil
from transformers import AutoTokenizer


CORPUS_VERSION = "wara2a-eval-2026-08-09-v1"
ARABIC_MONTHS = [
    "يناير",
    "فبراير",
    "مارس",
    "ابريل",
    "مايو",
    "يونيو",
    "يوليو",
    "اغسطس",
    "سبتمبر",
    "اكتوبر",
    "نوفمبر",
    "ديسمبر",
]
CURRENCY_ALIASES = {
    "EGP": ["EGP", "جنيه", "جنيه مصري", "ج م"],
    "USD": ["USD", "دولار", "دولار امريكي"],
    "EUR": ["EUR", "يورو"],
    "SAR": ["SAR", "ريال", "ريال سعودي"],
    "AED": ["AED", "درهم", "درهم اماراتي"],
    "GBP": ["GBP", "جنيه استرليني"],
}
MINOR_DIGITS = {"BHD": 3, "JOD": 3, "KWD": 3, "OMR": 3, "JPY": 0}
DIGIT_MAP = str.maketrans("٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹", "01234567890123456789")
DIACRITICS = re.compile(r"[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]")
BIDI = re.compile(r"[\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]")
QUERY_BIDI = re.compile(r"[\u200E\u200F\u202A-\u202E\u2066-\u2069]")
WHITESPACE = re.compile(r"\s+")
QUERY_UNSUPPORTED = re.compile(
    r'''[^\u0600-\u06FFa-z0-9<>=.,/"'+\-$\u20ac\u00a3]+'''
)


def _fold_full_width_ascii(value: str) -> str:
    output = []
    for character in value:
        code = ord(character)
        if 0xFF01 <= code <= 0xFF5E:
            output.append(chr(code - 0xFEE0))
        elif code == 0x3000:
            output.append(" ")
        else:
            output.append(character)
    return "".join(output)


def normalize_natural(value: str) -> str:
    normalized = _fold_full_width_ascii(value).lower()
    normalized = BIDI.sub("", normalized).replace("ـ", "")
    normalized = DIACRITICS.sub("", normalized)
    normalized = re.sub("[أإآٱ]", "ا", normalized)
    normalized = re.sub("[ىیۍې]", "ي", normalized)
    normalized = normalized.translate(DIGIT_MAP)
    normalized = normalized.replace("٫", ".").replace("٬", ",")
    return WHITESPACE.sub(" ", normalized).strip()


def normalize_query(value: str) -> str:
    normalized = _fold_full_width_ascii(value).lower().translate(DIGIT_MAP)
    normalized = QUERY_BIDI.sub("", normalized).replace("ـ", "")
    normalized = DIACRITICS.sub("", normalized)
    normalized = re.sub("[أإآٱ]", "ا", normalized)
    normalized = (
        normalized.replace("ى", "ي").replace("ؤ", "و").replace("ئ", "ي")
    )
    normalized = normalized.replace("٫", ".").replace("٬", ",")
    normalized = re.sub("[،؛؟٪]", " ", normalized)
    normalized = re.sub('[“”«»]', '"', normalized)
    normalized = re.sub("[‘’]", "'", normalized)
    normalized = re.sub("[–—−]", "-", normalized)
    normalized = normalized.replace("≥", ">=").replace("≤", "<=")
    normalized = QUERY_UNSUPPORTED.sub(" ", normalized)
    normalized = re.sub(r"\s*(>=|<=|>|<|=)\s*", r" \1 ", normalized)
    return WHITESPACE.sub(" ", normalized).strip()


def _format_quantity(value: float) -> str:
    if float(value).is_integer():
        return str(int(value))
    return f"{float(value):.3f}".rstrip("0").rstrip(".")


def _format_minor(value: int, currency: str | None) -> str:
    digits = MINOR_DIGITS.get(currency, 2)
    if digits == 0:
        return str(value)
    absolute = abs(value)
    divisor = 10**digits
    return (
        f"{'-' if value < 0 else ''}{absolute // divisor}."
        f"{absolute % divisor:0{digits}d}"
    )


def _arabic_month_year(value: str) -> str:
    date = datetime.fromisoformat(value[:10])
    return f"{ARABIC_MONTHS[date.month - 1]} {date.year}"


def _minor_from_major(value: Any, currency: str | None) -> int | None:
    if value is None:
        return None
    return round(float(value) * 10 ** MINOR_DIGITS.get((currency or "").upper(), 2))


def _add_months(date_text: str | None, months: int | None) -> str | None:
    if date_text is None or months is None:
        return None
    date = datetime.fromisoformat(date_text)
    month_index = date.month - 1 + months
    year = date.year + month_index // 12
    month = month_index % 12 + 1
    day = min(date.day, calendar.monthrange(year, month)[1])
    return f"{year:04d}-{month:02d}-{day:02d}"


def build_searchable_text(
    *,
    merchant: str | None = None,
    document_type: str | None = None,
    invoice_number: str | None = None,
    purchase_date: str | None = None,
    total_minor: int | None = None,
    currency: str | None = None,
    warranty_months: int | None = None,
    warranty_end_date: str | None = None,
    items: Iterable[tuple[str, float | None]] = (),
) -> tuple[str, str | None]:
    merchant = normalize_natural(merchant) if merchant and merchant.strip() else None
    document_type = (
        normalize_natural(document_type)
        if document_type and document_type.strip()
        else None
    )
    invoice_number = (
        normalize_natural(invoice_number)
        if invoice_number and invoice_number.strip()
        else None
    )
    currency = (
        normalize_natural(currency).upper() if currency and currency.strip() else None
    )

    items_by_name: dict[str, tuple[str, float | None]] = {}
    for raw_name, quantity in items:
        name = normalize_natural(raw_name) if raw_name and raw_name.strip() else None
        if name is None:
            continue
        key = re.sub(
            r"[^\u0621-\u063A\u0641-\u064A\u066E-\u06D3\u06FA-\u06FCa-z0-9]+",
            " ",
            name,
        )
        key = WHITESPACE.sub(" ", key).strip()
        if key not in items_by_name:
            items_by_name[key] = (name, quantity)
            continue
        old_name, old_quantity = items_by_name[key]
        combined = (
            quantity
            if old_quantity is None
            else old_quantity
            if quantity is None
            else old_quantity + quantity
        )
        items_by_name[key] = (old_name, combined)

    products = "، ".join(
        name if quantity is None else f"{name} × {_format_quantity(quantity)}"
        for name, quantity in items_by_name.values()
    )
    aliases = [] if currency is None else CURRENCY_ALIASES.get(currency, [currency])
    lines = []
    if document_type:
        lines.append(f"نوع المستند: {document_type}")
    if merchant:
        lines.append(f"المتجر: {merchant}")
    if invoice_number:
        lines.append(f"رقم الفاتورة: {invoice_number}")
    if products:
        lines.append(f"المنتجات: {products}")
    if total_minor is not None:
        suffix = "" if not aliases else " " + " ".join(aliases)
        lines.append(f"الاجمالي: {_format_minor(total_minor, currency)}{suffix}")
    if purchase_date:
        lines.append(
            f"تاريخ الشراء: {purchase_date[:10]}، "
            f"{_arabic_month_year(purchase_date)}"
        )
    if warranty_months is not None or warranty_end_date is not None:
        warranty = "الضمان:"
        if warranty_months is not None:
            warranty += f" {warranty_months} شهر"
        if warranty_end_date is not None:
            warranty += " " if warranty_months is None else "، "
            warranty += f"ينتهي {_arabic_month_year(warranty_end_date)}"
        lines.append(warranty)
    return "\n".join(lines), merchant


def _read_json_lines(path: Path) -> list[dict[str, Any]]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]


def _verify_normalization_contract(repo_root: Path) -> None:
    fixture = json.loads(
        (repo_root / "test/fixtures/search/reviewed_invoice_search_text.json").read_text(
            encoding="utf-8"
        )
    )
    for case in fixture["cases"]:
        source = case["input"]
        actual, _ = build_searchable_text(
            merchant=source.get("merchant"),
            document_type=source.get("documentType"),
            invoice_number=source.get("invoiceNumber"),
            purchase_date=source.get("purchaseDate"),
            total_minor=source.get("totalMinor"),
            currency=source.get("currencyCode"),
            warranty_months=source.get("warrantyMonths"),
            warranty_end_date=source.get("warrantyEndDate"),
            items=[(item["name"], item.get("quantity")) for item in source["items"]],
        )
        if actual != case["expected"]["searchableText"]:
            raise RuntimeError(f"Search-text normalization drifted for {case['id']}.")

    checks = [
        (
            "  \u0623\u064e\u0643\u0652\u062b\u064e\u0631 \u0645\u0650\u0646 "
            "\u0661\u0662\u066c\u0663\u0664\u0665\u066b\u0666\u0660 "
            "\u062c\u064f\u0646\u064e\u064a\u0652\u0647\u061f  ",
            "\u0627\u0643\u062b\u0631 \u0645\u0646 12,345.60 \u062c\u0646\u064a\u0647",
        ),
        (
            "Samsung \uff21\uff15\uff16 \u0641\u0648\u0642 \u06f1\u06f2\u06f3",
            "samsung a56 \u0641\u0648\u0642 123",
        ),
    ]
    if any(normalize_query(source) != expected for source, expected in checks):
        raise RuntimeError("Arabic query normalization drifted from its Dart contract.")


def _load_primary(repo_root: Path) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    invoices = _read_json_lines(
        repo_root / "test/fixtures/evaluation/invoices.jsonl"
    )
    raw_queries = _read_json_lines(
        repo_root / "test/fixtures/evaluation/search_queries.jsonl"
    )
    if len(invoices) != 50 or len(raw_queries) != 100:
        raise RuntimeError("Expected the checked-in 50-invoice/100-query corpus.")

    documents = []
    for invoice in invoices:
        expected = invoice["expected"]
        search = invoice["search"]
        purchase_date = expected["purchaseDate"]
        searchable, merchant = build_searchable_text(
            merchant=expected["merchant"],
            document_type=expected["documentType"],
            invoice_number=search["invoiceNumber"],
            purchase_date=purchase_date,
            total_minor=_minor_from_major(expected["total"], expected["currency"]),
            currency=expected["currency"],
            warranty_months=expected["warrantyMonths"],
            warranty_end_date=_add_months(purchase_date, expected["warrantyMonths"]),
            items=[
                (product["name"], product["quantity"])
                for product in expected["products"]
            ],
        )
        documents.append(
            {
                "id": invoice["caseId"],
                "text": f"title: {merchant or 'none'} | text: {searchable}",
            }
        )

    queries = [
        {
            "id": query["queryId"],
            "text": (
                "task: search result | query: " + normalize_query(query["text"])
            ),
            "language": query["language"],
            "route": query["expectedRoute"],
            "relevant": query["expectedInvoiceIds"],
        }
        for query in raw_queries
    ]
    return documents, queries


def _load_calibration(repo_root: Path, document_ids: set[str]) -> list[dict[str, Any]]:
    rows = _read_json_lines(
        repo_root
        / "test/fixtures/evaluation/semantic_search_calibration_queries.jsonl"
    )
    ids: set[str] = set()
    for row in rows:
        if row["corpusVersion"] != CORPUS_VERSION or row["schemaVersion"] != 1:
            raise RuntimeError(f"Unsupported calibration schema: {row['queryId']}")
        if row["queryId"] in ids:
            raise RuntimeError(f"Duplicate calibration ID: {row['queryId']}")
        ids.add(row["queryId"])
        language = row["language"]
        text = row["text"]
        has_arabic = re.search(r"[\u0600-\u06ff]", text) is not None
        has_latin = re.search(r"[a-zA-Z]", text) is not None
        valid_script = {
            "ar": has_arabic and not has_latin,
            "en": has_latin and not has_arabic and text.isascii(),
            "mixed": has_arabic and has_latin,
        }.get(language, False)
        if not valid_script:
            raise RuntimeError(
                f"Calibration language/script mismatch: {row['queryId']}"
            )
        expected = row["expectedInvoiceIds"]
        if row["kind"] == "positive" and not expected:
            raise RuntimeError(f"Positive query has no label: {row['queryId']}")
        if row["kind"] == "no_result" and expected:
            raise RuntimeError(f"No-result query has a positive label: {row['queryId']}")
        if any(invoice_id not in document_ids for invoice_id in expected):
            raise RuntimeError(f"Calibration query references an unknown invoice.")
    if not {"positive", "no_result"}.issubset({row["kind"] for row in rows}):
        raise RuntimeError("Calibration requires positive and no-result queries.")
    for language in ["ar", "en", "mixed"]:
        language_rows = [row for row in rows if row["language"] == language]
        counts = Counter(row["kind"] for row in language_rows)
        if counts != {"positive": 10, "no_result": 16}:
            raise RuntimeError(
                f"Expected 10 positives and 16 negatives for {language}, got {counts}."
            )
    return [
        {
            "id": row["queryId"],
            "text": "task: search result | query: " + normalize_query(row["text"]),
            "language": row["language"],
            "kind": row["kind"],
            "relevant": row["expectedInvoiceIds"],
        }
        for row in rows
    ]


class OnnxEmbedder:
    def __init__(
        self,
        *,
        model_dir: Path,
        onnx_model: Path,
        family: str,
        threads: int,
    ) -> None:
        self.family = family
        started = time.perf_counter()
        self.tokenizer = AutoTokenizer.from_pretrained(
            str(model_dir), local_files_only=True, use_fast=True
        )
        options = ort.SessionOptions()
        options.intra_op_num_threads = threads
        options.inter_op_num_threads = 1
        options.execution_mode = ort.ExecutionMode.ORT_SEQUENTIAL
        self.session = ort.InferenceSession(
            str(onnx_model),
            sess_options=options,
            providers=["CPUExecutionProvider"],
        )
        self.load_ms = (time.perf_counter() - started) * 1000
        self.input_names = {model_input.name for model_input in self.session.get_inputs()}
        self.outputs = [
            {
                "name": output.name,
                "shape": output.shape,
                "type": output.type,
            }
            for output in self.session.get_outputs()
        ]

    def _model_prompts(self, values: list[str], kind: str) -> list[str]:
        if self.family != "e5":
            return values
        prefix = "query: " if kind == "query" else "passage: "
        return [prefix + value for value in values]

    def encode(
        self, values: list[str], *, kind: str, batch_size: int
    ) -> tuple[np.ndarray, list[int]]:
        values = self._model_prompts(values, kind)
        vectors = []
        token_lengths = []
        for start in range(0, len(values), batch_size):
            batch = values[start : start + batch_size]
            tokens = self.tokenizer(
                batch,
                padding=True,
                truncation=True,
                max_length=256,
                return_tensors="np",
            )
            token_lengths.extend(
                tokens["attention_mask"].sum(axis=1).astype(int).tolist()
            )
            inputs = {
                key: value.astype(np.int64, copy=False)
                for key, value in tokens.items()
                if key in self.input_names
            }
            if "token_type_ids" in self.input_names and "token_type_ids" not in inputs:
                inputs["token_type_ids"] = np.zeros_like(
                    tokens["input_ids"], dtype=np.int64
                )
            hidden = self.session.run(None, inputs)[0]
            mask = tokens["attention_mask"].astype(np.float32)[..., None]
            pooled = (hidden * mask).sum(axis=1) / np.maximum(
                mask.sum(axis=1), 1e-9
            )
            norms = np.linalg.norm(pooled, axis=1, keepdims=True)
            if not np.isfinite(pooled).all() or not np.isfinite(norms).all():
                raise RuntimeError("Embedding output contains a non-finite value.")
            pooled = pooled / np.maximum(norms, 1e-12)
            if pooled.shape[1] != 384:
                raise RuntimeError(f"Expected 384 dimensions, got {pooled.shape[1]}.")
            vectors.append(pooled.astype(np.float32))
        return np.concatenate(vectors, axis=0), token_lengths


def _percentile(values: list[float], percentile: float) -> float:
    return float(np.percentile(np.asarray(values), percentile))


def _summary(values: list[float]) -> dict[str, float]:
    return {
        "min": min(values),
        "p05": _percentile(values, 5),
        "median": statistics.median(values),
        "p95": _percentile(values, 95),
        "max": max(values),
    }


def _rank(
    documents: list[dict[str, Any]],
    queries: list[dict[str, Any]],
    document_vectors: np.ndarray,
    query_vectors: np.ndarray,
) -> list[dict[str, Any]]:
    similarities = query_vectors @ document_vectors.T
    document_ids = [document["id"] for document in documents]
    rows = []
    for index, query in enumerate(queries):
        order = np.argsort(-similarities[index], kind="stable")
        ranked_ids = [document_ids[position] for position in order]
        ranks = [
            ranked_ids.index(relevant) + 1
            for relevant in query["relevant"]
            if relevant in ranked_ids
        ]
        relevant_distance = (
            min(
                1.0 - float(similarities[index, document_ids.index(relevant)])
                for relevant in query["relevant"]
            )
            if query["relevant"]
            else None
        )
        rows.append(
            {
                **query,
                "rank": min(ranks) if ranks else None,
                "predictedInvoiceId": ranked_ids[0],
                "top1CosineDistance": 1.0 - float(similarities[index, order[0]]),
                "relevantCosineDistance": relevant_distance,
                "top5": ranked_ids[:5],
            }
        )
    return rows


def _metrics(rows: list[dict[str, Any]]) -> dict[str, float | int | None]:
    if not rows:
        return {
            "n": 0,
            "recallAt1": None,
            "recallAt3": None,
            "recallAt5": None,
            "mrr": None,
        }
    ranks = [row["rank"] for row in rows]
    return {
        "n": len(rows),
        "recallAt1": sum(rank is not None and rank <= 1 for rank in ranks)
        / len(rows),
        "recallAt3": sum(rank is not None and rank <= 3 for rank in ranks)
        / len(rows),
        "recallAt5": sum(rank is not None and rank <= 5 for rank in ranks)
        / len(rows),
        "mrr": sum(0.0 if rank is None else 1.0 / rank for rank in ranks)
        / len(rows),
    }


def _language_calibration(rows: list[dict[str, Any]]) -> dict[str, Any]:
    positives = [row for row in rows if row["kind"] == "positive"]
    negatives = [row for row in rows if row["kind"] == "no_result"]
    positive_distances = [row["relevantCosineDistance"] for row in positives]
    negative_distances = [row["top1CosineDistance"] for row in negatives]
    all_positive_rank1 = all(row["rank"] == 1 for row in positives)
    max_positive = max(positive_distances)
    min_negative = min(negative_distances)
    separable = all_positive_rank1 and max_positive < min_negative
    threshold = (max_positive + min_negative) / 2.0 if separable else None
    return {
        "positiveMetrics": _metrics(positives),
        "positiveRelevantCosineDistance": _summary(positive_distances),
        "noResultTop1CosineDistance": _summary(negative_distances),
        "allPositiveRank1": all_positive_rank1,
        "strictlySeparable": separable,
        "separationMargin": min_negative - max_positive,
        "cohortMidGapThreshold": threshold,
    }


def _calibration_report(rows: list[dict[str, Any]]) -> dict[str, Any]:
    positives = [row for row in rows if row["kind"] == "positive"]
    negatives = [row for row in rows if row["kind"] == "no_result"]
    per_language = {
        language: _language_calibration(
            [row for row in rows if row["language"] == language]
        )
        for language in ["ar", "en", "mixed"]
    }
    all_languages_separable = all(
        report["strictlySeparable"] for report in per_language.values()
    )
    positive_distances = [row["relevantCosineDistance"] for row in positives]
    negative_distances = [row["top1CosineDistance"] for row in negatives]
    max_positive = max(positive_distances)
    min_negative = min(negative_distances)
    globally_separable = (
        all_languages_separable
        and all(row["rank"] == 1 for row in positives)
        and max_positive < min_negative
    )
    threshold = (
        (max_positive + min_negative) / 2.0 if globally_separable else None
    )
    accepted_positives = (
        sum(distance <= threshold for distance in positive_distances)
        if threshold is not None
        else None
    )
    accepted_negatives = (
        sum(distance <= threshold for distance in negative_distances)
        if threshold is not None
        else None
    )
    return {
        "scope": (
            "Balanced host calibration for Arabic, English, and mixed "
            "semantic/no-result queries. One threshold is emitted only when "
            "the raw distance distributions are globally separable."
        ),
        "perLanguage": per_language,
        "eachLanguageIndividuallySeparable": all_languages_separable,
        "globalPositiveRelevantCosineDistance": _summary(positive_distances),
        "globalNoResultTop1CosineDistance": _summary(negative_distances),
        "globallyStrictlySeparable": globally_separable,
        "globalSeparationMargin": min_negative - max_positive,
        "measuredGlobalThreshold": threshold,
        "thresholdRule": (
            "accept when ObjectBox-compatible cosine distance <= threshold"
            if threshold is not None
            else None
        ),
        "acceptedPositiveCount": accepted_positives,
        "positiveCount": len(positives),
        "falseAcceptedNoResultCount": accepted_negatives,
        "noResultCount": len(negatives),
        "rows": [
            {
                "queryId": row["id"],
                "language": row["language"],
                "kind": row["kind"],
                "expectedInvoiceIds": row["relevant"],
                "predictedInvoiceId": row["predictedInvoiceId"],
                "rank": row["rank"],
                "top1CosineDistance": row["top1CosineDistance"],
                "relevantCosineDistance": row["relevantCosineDistance"],
            }
            for row in rows
        ],
    }


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(8 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _artifact(path: Path) -> dict[str, Any]:
    return {"path": str(path.resolve()), "bytes": path.stat().st_size, "sha256": _sha256(path)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--family", choices=["e5", "minilm"], required=True)
    parser.add_argument("--model-dir", type=Path, required=True)
    parser.add_argument("--onnx-model", type=Path, required=True)
    parser.add_argument("--revision", required=True)
    parser.add_argument("--license", required=True)
    parser.add_argument("--label", required=True)
    parser.add_argument("--threads", type=int, default=6)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    _verify_normalization_contract(repo_root)
    documents, primary_queries = _load_primary(repo_root)
    calibration_queries = _load_calibration(
        repo_root, {document["id"] for document in documents}
    )

    process = psutil.Process()
    rss_before = process.memory_info().rss
    embedder = OnnxEmbedder(
        model_dir=args.model_dir.resolve(),
        onnx_model=args.onnx_model.resolve(),
        family=args.family,
        threads=args.threads,
    )
    rss_after_load = process.memory_info().rss

    document_vectors, document_tokens = embedder.encode(
        [document["text"] for document in documents],
        kind="document",
        batch_size=16,
    )
    primary_vectors, primary_tokens = embedder.encode(
        [query["text"] for query in primary_queries], kind="query", batch_size=16
    )
    primary_rows = _rank(
        documents, primary_queries, document_vectors, primary_vectors
    )

    calibration_vectors, calibration_tokens = embedder.encode(
        [query["text"] for query in calibration_queries],
        kind="query",
        batch_size=16,
    )
    calibration_rows = _rank(
        documents, calibration_queries, document_vectors, calibration_vectors
    )

    embedder.encode([primary_queries[0]["text"]], kind="query", batch_size=1)
    single_latencies = []
    for query in primary_queries:
        started = time.perf_counter()
        embedder.encode([query["text"]], kind="query", batch_size=1)
        single_latencies.append((time.perf_counter() - started) * 1000)

    tokenizer_files = [
        path
        for path in [
            args.model_dir / "sentencepiece.bpe.model",
            args.model_dir / "tokenizer.json",
            args.model_dir / "tokenizer_config.json",
            args.model_dir / "special_tokens_map.json",
        ]
        if path.is_file()
    ]
    result = {
        "schemaVersion": 1,
        "evidenceClass": "host_only_real_model_inference",
        "model": {
            "label": args.label,
            "family": args.family,
            "revision": args.revision,
            "license": args.license,
            "onnx": _artifact(args.onnx_model),
            "tokenizerFiles": [_artifact(path) for path in tokenizer_files],
            "outputs": embedder.outputs,
            "pooling": (
                "external attention-mask mean pooling followed by finite L2 "
                "normalization; the ONNX output is token-level"
            ),
            "promptContract": (
                "E5 canonical query:/passage: wraps Wara2a task:/title: prompts; "
                "MiniLM uses Wara2a prompts directly"
            ),
            "maximumTokens": 256,
        },
        "corpus": {
            "documents": len(documents),
            "primaryQueries": len(primary_queries),
            "primaryLanguageCounts": dict(
                Counter(query["language"] for query in primary_queries)
            ),
            "primaryRouteCounts": dict(
                Counter(query["route"] for query in primary_queries)
            ),
            "calibrationQueries": len(calibration_queries),
            "calibrationLanguageCounts": dict(
                Counter(query["language"] for query in calibration_queries)
            ),
            "calibrationKindCounts": dict(
                Counter(query["kind"] for query in calibration_queries)
            ),
        },
        "primaryAllRoute": {
            "warning": (
                "This aggregate intentionally includes keyword and structured "
                "labels; it cannot approve a semantic distance threshold."
            ),
            "all": _metrics(primary_rows),
            "byLanguage": {
                language: _metrics(
                    [row for row in primary_rows if row["language"] == language]
                )
                for language in ["ar", "en", "mixed"]
            },
            "byRoute": {
                route: _metrics(
                    [row for row in primary_rows if row["route"] == route]
                )
                for route in sorted({row["route"] for row in primary_rows})
            },
        },
        "multilingualSemanticCalibration": _calibration_report(calibration_rows),
        "host": {
            "platform": platform.platform(),
            "python": platform.python_version(),
            "onnxRuntime": ort.__version__,
            "logicalCpu": os.cpu_count(),
            "physicalCpu": psutil.cpu_count(logical=False),
            "threads": args.threads,
            "coldTokenizerAndSessionLoadMs": embedder.load_ms,
            "warmSingleQueryP50Ms": _percentile(single_latencies, 50),
            "warmSingleQueryP95Ms": _percentile(single_latencies, 95),
            "rssBeforeBytes": rss_before,
            "rssAfterLoadBytes": rss_after_load,
            "rssLoadDeltaBytes": rss_after_load - rss_before,
            "rssAfterBenchmarkBytes": process.memory_info().rss,
            "documentTokenMax": max(document_tokens),
            "primaryQueryTokenMax": max(primary_tokens),
            "calibrationQueryTokenMax": max(calibration_tokens),
        },
        "limits": [
            "Host CPU execution is not Android arm64 or release-build evidence.",
            "The threshold, when present, is provisional for the balanced small multilingual semantic/no-result fixture.",
            "No model weights are written into the repository.",
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(result, ensure_ascii=True))


if __name__ == "__main__":
    main()
