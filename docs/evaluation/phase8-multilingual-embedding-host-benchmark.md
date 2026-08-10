# Phase 8 multilingual embedding host benchmark

- Evidence date: 2026-08-10
- Evidence class: real model inference on a Windows x64 host, not Android proof
- Corpus commit at benchmark start: `2766c2df2b17207de3d261421071bf1aa8bbbfe6`

## Decision

Select the **`intfloat/multilingual-e5-small` model family** for the bounded
Android spike. Reject
`sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2` for Wara2a's
retrieval contract: its official qint8 ARM64 ONNX artifact missed the semantic
quality bar substantially.

This is not an Android approval. The tested E5 qint8 file is upstream's
`model_qint8_avx512_vnni.onnx`. Its graph contains only standard ONNX ops, but
its published filename is x86-specific. It must not be relabeled as Android
compatible until the exact graph is loaded and queried on the RMX3636, or an
Android-safe E5 quantization is generated reproducibly and then verified on
that device.

## Pinned candidates

| Candidate | Revision | Model file | Bytes | SHA-256 | License evidence |
| --- | --- | --- | ---: | --- | --- |
| multilingual-e5-small qint8 host artifact | `614241f622f53c4eeff9890bdc4f31cfecc418b3` | `onnx/model_qint8_avx512_vnni.onnx` | 118,346,824 | `dd476dd0c2514e9b9be83aeb3853fac0763e0bdf4a71645407587d77c48a2d88` | MIT in pinned model-card YAML |
| multilingual-e5-small generic FP32 reference | same | `onnx/model.onnx` | 470,268,510 | `ca456c06b3a9505ddfd9131408916dd79290368331e7d76bb621f1cba6bc8665` | MIT in pinned model-card YAML |
| paraphrase-multilingual-MiniLM-L12-v2 qint8 ARM64 | `e8f8c211226b894fcb81acc59f3b34ba3efd5f42` | `onnx/model_qint8_arm64.onnx` | 118,412,398 | `783fea82d71a58179b830a4dbd2d58447e640609e98eedf9ffa12622d375a672` | Apache-2.0 in pinned model-card YAML |

Both public snapshots downloaded without authentication or a Hugging Face
token. They share the same SentencePiece model: 5,069,051 bytes, SHA-256
`cfc8146abe2a0488e9e2a0c56de7952f7c11ab059eca145a0a727afce0db2865`.
The E5 qint8 model plus that tokenizer is 123,415,875 bytes before any
tokenizer-in-graph packaging.

The pinned E5 card's prose says the model supports 100 XLM-R languages; its
current YAML enumerates 94 entries including the `multilingual` tag and
explicit `ar` and `en` tags. The pinned MiniLM YAML enumerates 50 entries
including `multilingual`, `ar`, and `en`. The real corpus results below, rather
than those metadata counts, are the evidence used for Arabic, English, and
mixed-script behavior.

Primary sources:

- [Pinned multilingual-e5-small model card](https://huggingface.co/intfloat/multilingual-e5-small/blob/614241f622f53c4eeff9890bdc4f31cfecc418b3/README.md)
- [Pinned multilingual-e5-small ONNX files](https://huggingface.co/intfloat/multilingual-e5-small/tree/614241f622f53c4eeff9890bdc4f31cfecc418b3/onnx)
- [Pinned multilingual MiniLM model card](https://huggingface.co/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2/blob/e8f8c211226b894fcb81acc59f3b34ba3efd5f42/README.md)
- [Pinned multilingual MiniLM ONNX files](https://huggingface.co/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2/tree/e8f8c211226b894fcb81acc59f3b34ba3efd5f42/onnx)

Neither snapshot contains a standalone `LICENSE` file. Redistribution review
must therefore retain the standard license notices corresponding to the
model-card SPDX values and verify transitive runtime notices before release.

## Method

The benchmark reads the checked-in 50 invoices and builds the same natural
search text as `InvoiceSearchTextBuilder`. The Python port self-checks all
three reviewed Arabic/English/mixed production goldens before inference. Its
query normalizer also self-checks the two principal Arabic normalization
examples from the Dart tests.

Inputs retain Wara2a's planned prompts:

- document: `title: {merchant or "none"} | text: {normalized searchable text}`
- query: `task: search result | query: {normalized query}`

E5 additionally requires its official outer `passage: ` and `query: `
prefixes. MiniLM receives the Wara2a prompts directly. Both runs use the
official fast tokenizer from the pinned snapshot, truncate at 256 tokens, run
the ONNX graph through ONNX Runtime CPU, apply attention-mask mean pooling to
the token-level `[batch, sequence, 384]` output, and then validate finite
384-dimensional L2-normalized vectors. Pooling and normalization are not
inside either downloaded graph.

## Checked-in 50-invoice/100-query results

The primary query file contains 52 Arabic and 48 mixed queries, but **zero
English-only queries**. Each route has 25 labels. Raw dense retrieval is shown
for completeness; the 25 structured labels are intentionally not a semantic
model task and make the all-route aggregate unsuitable for threshold approval.

### multilingual-e5-small qint8

| Cohort | n | Recall@1 | Recall@3 | Recall@5 | MRR |
| --- | ---: | ---: | ---: | ---: | ---: |
| All routes | 100 | 0.7300 | 0.7600 | 0.7700 | 0.7564 |
| Arabic | 52 | 0.7500 | 0.7692 | 0.7885 | 0.7721 |
| Mixed | 48 | 0.7083 | 0.7500 | 0.7500 | 0.7394 |
| English | 0 | n/a | n/a | n/a | n/a |
| Semantic route | 25 | 1.0000 | 1.0000 | 1.0000 | 1.0000 |
| Hybrid route | 25 | 1.0000 | 1.0000 | 1.0000 | 1.0000 |
| Keyword route forced through dense retrieval | 25 | 0.9200 | 1.0000 | 1.0000 | 0.9533 |
| Structured route forced through dense retrieval | 25 | 0.0000 | 0.0400 | 0.0800 | 0.0723 |

### multilingual MiniLM qint8 ARM64

| Cohort | n | Recall@1 | Recall@3 | Recall@5 | MRR |
| --- | ---: | ---: | ---: | ---: | ---: |
| All routes | 100 | 0.2100 | 0.3600 | 0.4900 | 0.3359 |
| Arabic | 52 | 0.1923 | 0.3654 | 0.4423 | 0.3075 |
| Mixed | 48 | 0.2292 | 0.3542 | 0.5417 | 0.3666 |
| English | 0 | n/a | n/a | n/a | n/a |
| Semantic route | 25 | 0.3600 | 0.5600 | 0.6800 | 0.4977 |
| Hybrid route | 25 | 0.1600 | 0.1600 | 0.2800 | 0.2386 |

E5 is the only candidate that meets the documented semantic Recall@5 >= 0.90
bar on the actual semantic cohort. MiniLM is rejected despite having a clearly
named upstream ARM64 artifact and slightly lower host latency.

## Multilingual semantic/no-result calibration

`test/fixtures/evaluation/semantic_search_calibration_queries.jsonl` contains
10 positives and 16 honest no-result negatives for each of Arabic-only,
English-only, and mixed Arabic/English: 78 queries total. Each family-level
positive labels all five materially equivalent repeated synthetic invoices as
relevant; it does not pretend an arbitrary record is uniquely relevant when a
query contains no date or invoice number.

Real E5 qint8 results:

| Language | Positive n | R@1 | R@3 | R@5 | MRR | Positive distance min/max | Negative top-1 distance min/max | Within-language margin |
| --- | ---: | ---: | ---: | ---: | ---: | --- | --- | ---: |
| Arabic | 10 | 1.0000 | 1.0000 | 1.0000 | 1.0000 | `0.078743994` / `0.131664634` | `0.134062886` / `0.174938679` | `0.002398252` |
| English | 10 | 1.0000 | 1.0000 | 1.0000 | 1.0000 | `0.111351371` / `0.152949154` | `0.182088733` / `0.216191292` | `0.029139578` |
| Mixed | 10 | 1.0000 | 1.0000 | 1.0000 | 1.0000 | `0.088200212` / `0.110158563` | `0.135209262` / `0.172229230` | `0.025050700` |

Every language is internally separable with zero false accepts at its own
mid-gap threshold (`0.132863760` Arabic, `0.167518944` English,
`0.122683913` mixed). However, the raw distance scales overlap across
languages: the global positive maximum is `0.152949154`, while the global
negative minimum is `0.134062886`, a negative global margin of
`-0.018886268`.

Therefore **no single global cosine-distance threshold is approved** and the
machine-readable result emits `measuredGlobalThreshold: null`. Choosing
`0.134062886` or lower would avoid false accepts in this fixture but reject
valid English positives; choosing high enough to retain those positives would
false-accept Arabic or mixed negatives. The result must not be forced into a
global threshold. A future decision may evaluate language-conditioned
calibration, but that is a different production contract and still needs the
exact Android model/tokenizer/runtime path on the RMX3636.

## Host timing and memory

Host: Windows 11 build 26200, Intel Core i7-9750H (6 physical/12 logical
cores), 34,223,542,272 bytes RAM, Python 3.11.15, ONNX Runtime 1.22.1, six
intra-op threads.

Comparable bounded runs:

| Candidate | Cold tokenizer + session | Warm query p50 | Warm query p95 | RSS load delta |
| --- | ---: | ---: | ---: | ---: |
| E5 qint8 | 2,760.6 ms | 17.60 ms | 32.54 ms | 432,013,312 B |
| MiniLM qint8 ARM64 | 2,309.1 ms | 14.49 ms | 25.37 ms | 428,769,280 B |

These timings exclude ObjectBox retrieval and are host-only. They do not
replace Android latency, RAM, or thermal measurements.

## Reproduction

The run used an isolated Python 3.11.15 environment with:

```text
numpy==2.3.2
onnxruntime==1.22.1
transformers==4.55.2
huggingface-hub==0.34.4
sentencepiece==0.2.1
psutil==7.0.0
```

After downloading and verifying the pinned snapshot outside the repository:

```powershell
$bench = 'C:\path\to\isolated\venv\Scripts\python.exe'
$snapshot = 'C:\path\to\multilingual-e5-small-snapshot'

& $bench tool/evaluation/benchmark_multilingual_embeddings.py `
  --repo-root . `
  --family e5 `
  --model-dir $snapshot `
  --onnx-model "$snapshot\onnx\model_qint8_avx512_vnni.onnx" `
  --revision 614241f622f53c4eeff9890bdc4f31cfecc418b3 `
  --license MIT `
  --label intfloat-multilingual-e5-small-qint8-upstream-host `
  --output C:\path\outside\repo\e5-host-results.json
```

The script writes per-query calibration distances to the requested external
JSON result. Model weights and generated result files are deliberately not
committed.
