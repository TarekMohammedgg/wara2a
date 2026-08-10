# Wara2a synthetic evaluation corpus

This repository contains a deterministic, privacy-safe evaluation corpus for
the Phase 7 OCR/extraction work and the Phase 9-10 retrieval/router work.
It contains no photographed invoices, personal data, cloud references, model
outputs, or binary image set.

Corpus version: `wara2a-eval-2026-08-09-v1`

## Files and generation

- `test/fixtures/evaluation/invoices.jsonl` contains exactly 50 synthetic
  invoice cases.
- `test/fixtures/evaluation/search_queries.jsonl` contains exactly 100 Arabic
  or Arabic/Latin mixed labeled queries.
- `test/fixtures/evaluation/semantic_search_calibration_queries.jsonl`
  contains separate, balanced Arabic-only, English-only, and mixed
  Arabic/English semantic calibration cohorts. Each language has family-level
  positive labels and honest no-result negatives. It exists to measure
  candidate-model retrieval and rejection distances; it does not change the
  100-query route corpus or approve a threshold unless one raw global distance
  cutoff separates all three languages.
- `tool/evaluation/generate_corpus.dart` is the deterministic generator. Run
  `dart run tool/evaluation/generate_corpus.dart` from the repository root to
  reproduce both JSONL files.
- `test/evaluation/evaluation_corpus.dart` parses and validates the schema and
  provides extraction and retrieval scoring helpers.
- `test/evaluation/evaluation_corpus_test.dart` is the fast contract suite.

The generator uses fixed arrays, seed-free index arithmetic, and fixed dates;
re-running it must produce the same files. There are no generated image files
in Git. Each invoice has a `synthetic-text-render-spec` with dimensions,
source lines, digit script, date style, layout, glare, skew, contrast, and
occlusion metadata. A later device test may render those specs with a pinned
font/rendering environment, but the corpus itself remains compact JSONL.

## Invoice schema

Each invoice record has these top-level fields:

- `caseId`, `corpusVersion`, `language` (`ar`, `en`, or `mixed`), and `layout`
  (`thermal` or `a4`).
- `source`: a render specification containing `textLines`, image dimensions,
  Arabic-Indic/Persian/Latin `digitScript`, and date style.
- `conditions`: `glare` (`none`, `mild`, `strong`), `skewDegrees`, `contrast`
  (`normal`, `low`), and `occlusion`.
- `obscuredFields`: fields intentionally present but unreadable, such as
  `total` or `products[0].lineTotal`.
- `nullFields`: fields intentionally absent, such as an invoice without a
  warranty.
- `expected`: the Phase 7 structured extraction contract:
  `merchant`, `documentType`, `purchaseDate`, `total`, `currency`,
  `products`, `warrantyMonths`, and `rawText`. Missing/obscured values are
  explicitly `null`.
- `search`: synthetic invoice number and deterministic metadata used only to
  label retrieval queries. It is not model output.

The corpus rotates thermal and A4 layouts; Arabic, English, and mixed source
text; Latin, Arabic-Indic, and Persian digits; ISO and slash dates; EGP, SAR,
AED, USD, EUR, and JOD; glare, skew, low contrast; and both null and obscured
fields.

## Physical-device OCR consumption

The device harness should, for every invoice record:

1. Render `source.textLines` using the record's layout, dimensions, digit
   script, date style, and `conditions`. Keep the image outside Git and name it
   from `source.renderId`.
2. Run the real PaddleOCR pipeline in airplane mode and capture ordered text,
   recognizer/script, confidence, boxes, OCR duration, and preprocessing
   settings. Do not replace this with fixture text when measuring quality.
3. Compare OCR output to `source.textLines.join("\\n")` after recording both
   raw and evaluation-normalized text. Keep OCR scoring separate from Qwen
   structured extraction scoring.
4. Pass only the captured OCR evidence to the text interpreter, validate its
   JSON with the app validator, and compare to `expected`.

Required extraction metrics:

- Character error rate (CER):
  `Levenshtein(predicted characters, gold characters) / gold characters`.
- Word error rate (WER): the same formula over whitespace/tokenized words.
- Schema parse rate: valid typed outputs divided by inference attempts.
- Per-field exact accuracy for `total`, ISO `purchaseDate`, and currency.
- Normalized merchant accuracy: trim/case/whitespace-normalized equality.
- Product item precision, recall, and F1 by normalized product name; report
  the macro average and the case-level distribution.
- Null/obscured preservation: expected null fields that remain null, reported
  separately for `nullFields` and `obscuredFields`.
- Warm/cold OCR, interpreter, total latency, peak memory, and ten-sequential
  run stability by device tier and image condition.

The corpus does not claim any metric has passed. The plan's extraction quality
gate and device limits must be approved after real model inference.

## Retrieval and Phase 10 router consumption

For every query record, run the production-local route selection and record:

- predicted route (`keyword`, `structured`, `semantic`, or `hybrid`),
- predicted filters, and
- ordered invoice IDs returned by local retrieval/filtering.

Semantic document/query encoding must use the exact prompts in `plan.md`:

- document: `title: {merchant or "none"} | text: {normalized searchable text}`
- query: `task: search result | query: {normalized query}`

The expected IDs are relevance labels, not a claim that the current mock or
future model already returns them. Queries cover merchant/product/invoice
number keywords, amount/date/currency/document/warranty filters, descriptive
Arabic intent, and mixed filter plus descriptive intent.

Required retrieval/router metrics:

- Recall@1: queries with at least one expected ID in the first result divided
  by all queries.
- Recall@5: the same over the first five results.
- MRR: mean reciprocal rank of the first expected ID, zero when absent.
- False-positive rate @5: non-expected IDs in the first five divided by all
  returned IDs in those five slots; report empty-result count separately.
- Route accuracy: exact match between `expectedRoute` and the predicted route.
- Filter exactness: exact key/value match for the expected filter object,
  reported for structured and hybrid queries separately.
- Query embedding + local retrieval latency, p50/p95 warm and cold model-load
  latency, and missing-embedding/no-result behavior.

The plan's `Recall@5 >= 0.90` and warm `<= 750 ms p95` values are release gates,
not results from this fixture suite. No quality threshold is considered passed
until the corpus is run with the approved on-device models and device matrix.

The host-only E5/MiniLM run and multilingual calibration are recorded in
`docs/evaluation/phase8-multilingual-embedding-host-benchmark.md`. Any measured
host threshold in that report remains provisional until the exact Android
runtime is evaluated.

## Fast validation

Run:

```text
flutter test test/evaluation/evaluation_corpus_test.dart
```

The tests prove the exact 50/100 counts, unique IDs, query-to-invoice
references, schema shape, and category coverage. They also lock the formulas
for Recall@1, Recall@5, MRR, false-positive rate @5, normalized field
accuracy, and product-name F1 without requiring a model, network, database, or
image renderer.
