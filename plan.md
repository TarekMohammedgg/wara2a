# Wara2a — Offline Invoice Intelligence Implementation Plan

> Status: Android-first implementation is integrated and release-QA tested, but the MVP is **not complete**. Deterministic tests, Android native unit tests, and arm64 APK builds are passing for the non-embedding stack; offline multilingual semantic search now targets `intfloat/multilingual-e5-small` qint8 through ONNX Runtime Android + Extensions, but release acceptance remains blocked by physical E5 load/query proof, Android-approved calibration, extraction-quality, device-matrix, offline-install, and Apple-platform gates listed below.
>
> Research snapshot: 2026-08-09. Mobile AI packages and runtimes are changing quickly; Phase 1 must re-check all pinned versions before installation.

> QA snapshot: 2026-08-10. Host-only multilingual embedding evidence selected MIT-licensed `intfloat/multilingual-e5-small` qint8 over MiniLM; EmbeddingGemma was abandoned because it is license-gated and absent. The Android ORT + Extensions MethodChannel, ObjectBox 384-d migration, Settings/Search E5 UI, and arm64 debug/release APKs are implemented and host-validated. Physical RMX3636 E5 install/inference, airplane-mode retrieval, and release calibration remain open because the reference device was unavailable for the final smoke after the APKs were produced.

## 1. Product definition and boundaries

Wara2a is an Arabic-first, privacy-focused mobile application that captures or imports an invoice, extracts structured information locally, lets the user review and correct the result, stores the invoice and image locally, and later retrieves invoices through Arabic or mixed Arabic/English search.

The MVP is offline-first and has no authentication, Firebase, Supabase, remote inference API, cloud vector database, cloud sync, analytics SDK, chatbot, or background warranty automation. Network access may be used only to install model files before offline use. After the required models are installed, capture, extraction, review, save, and search must work in airplane mode.

The architecture remains:

- MVVM.
- Feature-based organization.
- Cubit for state management.
- `SharedPreferences` for simple non-critical settings only.
- ObjectBox for invoices, items, metadata, and embeddings.
- UI-first implementation with mocks before any native AI integration.

The AI result is always a draft. No extracted invoice may be persisted until the review screen is shown and the user explicitly confirms it.

## 2. Executive technical decisions

### 2.1 Extraction pipeline

Use a lightweight, fully local two-stage extraction pipeline instead of a direct multimodal model:

```text
Invoice image
  -> PaddleOCR PP-OCRv5 detects and recognizes Arabic/English text
  -> OCR lines, bounding boxes, script, and confidence are normalized
  -> Qwen2.5-0.5B-Instruct converts the OCR evidence into strict JSON
  -> Dart parses and validates a typed InvoiceDraft
  -> the mandatory Review/Edit screen is opened
```

Stage 1 — OCR:

- Use PP-OCRv5 mobile detection plus `arabic_PP-OCRv5_mobile_rec` for Arabic letters/digits.
- Use `en_PP-OCRv5_mobile_rec` or `latin_PP-OCRv5_mobile_rec` for English/Latin text and digits; choose the final recognizer from the device evaluation rather than assuming one recognizer handles mixed invoices equally well.
- Preserve recognized text, line order, bounding boxes, script choice, and confidence. Qwen receives OCR evidence, not only one flattened string.
- Route crops to the Arabic or English/Latin recognizer using lightweight script detection; run both only for uncertain/mixed crops to avoid doubling OCR work.
- The Arabic mobile recognizer is approximately 7.6 MB and the Latin recognizer is approximately 14 MB; the complete OCR footprint also includes detection, optional orientation, runtime libraries, and token dictionaries.

Stage 2 — text understanding:

- Use **Qwen2.5-0.5B-Instruct** as the primary extraction language model.
- Official model repository: `Qwen/Qwen2.5-0.5B-Instruct`.
- Mobile LiteRT community repository: `litert-community/Qwen2.5-0.5B-Instruct`.
- The documented LiteRT model size is approximately **521 MB**.
- Qwen2.5 supports Arabic and English, improved structured-data understanding, and JSON generation. Wara2a limits prompts and evaluation to Arabic and English invoices even though the model supports additional languages.
- Qwen never receives or interprets the image directly. PaddleOCR is the only image-reading stage in this MVP.

The expected extraction stack is approximately **550–650 MB** before the E5 encoder, depending on the selected OCR detector/runtime and packaged dictionaries. Record the actual APK/AAB and installed-model sizes during the Phase 7/8 device spikes.

Do not add a direct vision-language fallback to the MVP. If the pipeline fails the approved quality gates, first improve OCR preprocessing, mixed-script routing, normalization, and deterministic parsing; reconsider a direct VLM only through a separate architecture decision.

### 2.2 Inference runtime and Flutter integration

Use two app-owned native/runtime boundaries:

- `OcrEngine` runs PaddleOCR/PP-OCRv5 locally and returns ordered `OcrLine` values with bounding boxes, script, and confidence. Begin with Paddle Lite native integration behind Android/iOS bridges; pin the exact runtime and model artifacts only after the physical-device spike.
- `InvoiceTextInterpreter` runs Qwen2.5-0.5B-Instruct through LiteRT-LM and accepts normalized OCR evidence as text. It returns strict JSON only and has no image API.

Primary Flutter integration:

- `flutter_gemma` core package plus `flutter_gemma_litertlm` for the Qwen text model, pinned only after confirming the selected versions load `Qwen2.5-0.5B-Instruct` on both target platforms.
- Native Paddle Lite integration behind narrow Platform Channels for OCR; do not expose Paddle-specific types above `OcrEngine`.
- Keep OCR and Qwen adapters replaceable independently so the app can change an OCR runtime without changing Cubits, validation, or review UI.

Complete an Android physical-device feasibility spike before installing permanent package versions. The spike must prove Arabic, English, and mixed-script OCR; Qwen model loading; strict JSON generation; cancellation; disposal; and ten sequential runs.

Contingency if the Flutter package fails a release gate:

- Android Qwen contingency: use the stable Kotlin SDK artifact `com.google.ai.edge.litertlm:litertlm-android`, pinning a concrete version rather than `latest.release`.
- Expose narrow OCR methods such as `initializeOcr`, `recognizeInvoice`, `cancelOcr`, and `disposeOcr`; expose equivalent independent methods for the Qwen interpreter.
- Use an `EventChannel` only for meaningful load/download/inference progress events.
- iOS: do not claim support until both PaddleOCR and Qwen pass a signed physical-device spike. Keep the UI and Dart validation cross-platform while native support remains independently gated.

### 2.3 Platform scope and practical device floor

The practical MVP is **Android-first**. Flutter UI, MVVM code, normalization, and ObjectBox repositories remain cross-platform, but release readiness for on-device AI is decided independently per platform.

Android target:

- 64-bit ARM (`arm64-v8a`) initially for PaddleOCR, LiteRT-LM, and the embedding path unless the selected runtimes publish verified additional ABIs.
- Product target: Android 10 or later, subject to the exact dependency `minSdk` resolved in Phase 1.
- Evaluate 4 GB devices as the new minimum candidate tier; use 6 GB as the recommended reference tier until measurements define the final floor.
- Require at least 1.5 GB free storage before model installation to accommodate Qwen (~521 MB), OCR models/runtime, the approximately 180–200 MB embedding stack, caches, temporary downloads, invoice images, and atomic model replacement.
- GPU is preferred where stable; CPU fallback is required. NPU support is not an MVP dependency.
- A 4 GB device remains unsupported if the Phase 7 sequential extraction and memory-pressure gates fail.

iOS target:

- Physical `arm64` devices only.
- iOS 16 or later for the current Flutter inference integration; ObjectBox itself requires iOS 15, so iOS 16 is the effective project floor.
- Evaluate 4 GB and 6 GB physical devices before declaring the practical tier.
- The iOS simulator is not acceptance evidence for OCR or language-model performance.
- iOS release support remains provisional until model loading, image extraction, memory pressure, App Store signing, and background/foreground behavior pass on physical hardware.

Published Qwen text-model throughput does not represent the complete invoice workflow. Measure image preprocessing, OCR detection/recognition, normalization, Qwen initialization/generation, JSON validation, and review navigation separately and end to end.

Planning performance gates, to be measured rather than assumed:

- Warm OCR plus extraction: <= 15 seconds at p95 on the chosen Android reference device.
- Cold OCR plus extraction: <= 25 seconds at p95, including OCR and Qwen initialization.
- Search query embedding plus local retrieval: <= 750 ms warm at p95.
- No UI frame stall longer than 100 ms attributable to Dart-side work.
- No crash or OS kill during ten sequential invoice extractions.

### 2.4 Structured extraction output

Qwen must convert only the supplied OCR evidence into one strict JSON object matching the app-owned schema. Do not depend on free-form prose, markdown fences, or image reasoning. If the selected runtime supports a compatible constrained JSON grammar, enable and test it; otherwise use deterministic JSON extraction plus the typed Dart validator.

Define one strict extraction schema:

```text
merchant: string | null
documentType: string | null
purchaseDate: ISO-8601 date string | null
total: number | null
currency: ISO-4217 code or literal invoice currency | null
products: array of {
  name: string | null
  quantity: number | null
  unitPrice: number | null
  lineTotal: number | null
}
warrantyMonths: integer | null
rawText: string | null
```

Prompt invariants:

- Read only the supplied OCR lines and their spatial metadata.
- Preserve Arabic and English names as printed.
- Treat low-confidence or conflicting OCR evidence as uncertain.
- Return `null` when a value is absent, obscured, or uncertain.
- Never infer a merchant, date, price, currency, product, or warranty from general knowledge.
- Do not calculate a missing value from assumptions.
- Return exactly one JSON object without markdown or commentary.

Validation sequence:

1. Parse the JSON into a typed `InvoiceDraft`.
2. Reject unknown keys and invalid types.
3. Validate ISO dates, non-negative quantities, plausible money bounds, currency format, and list size limits.
4. Cross-check important values against OCR evidence and deterministic rules, including subtotal/tax/total consistency where values are present.
5. If the output is invalid, allow one schema-repair retry using only validation errors and the original OCR evidence.
6. If it remains invalid, open a blank/manual review draft, preserve the raw OCR text, and show a recoverable error state.
7. Convert monetary values to integer minor units before persistence; do not store money as binary floating point.

Structured syntax reliability and extraction correctness are different. Constrained output can make the payload parseable but cannot make a hallucinated total true. The review step and field validation remain mandatory.

### 2.5 Embedding model

Use **`intfloat/multilingual-e5-small`** through ONNX Runtime Android and the official ONNX Runtime Extensions tokenizer. EmbeddingGemma is rejected for this MVP: it is license-gated, unavailable without approved access, and was never loaded on the reference device.

Pinned deployable contract:

- Repository: `intfloat/multilingual-e5-small`
- Revision: `614241f622f53c4eeff9890bdc4f31cfecc418b3`
- File: `onnx/model_qint8_avx512_vnni.onnx` (118,346,824 bytes)
- SHA-256: `dd476dd0c2514e9b9be83aeb3853fac0763e0bdf4a71645407587d77c48a2d88`
- License: MIT
- Dimensions: 384
- Schema version: 3
- Runtime: ONNX Runtime Android `1.21.1` + ONNX Runtime Extensions Android `0.13.0`
- Tokenizer: bundled ORT Extensions SentencePiece preprocessing graph only; no encoder weights in Git
- Official retrieval prefixes: `query: ` and `passage: `, combined with Wara2a's existing `task: search result | query:` / `title: ... | text: ...` formatting

Host-only evidence (not Android approval):

- Semantic and hybrid Recall@1/3/5 and MRR: **1.0**
- MiniLM rejected: semantic Recall@1/3/5 = 0.36/0.56/0.68, MRR = 0.498
- Structured queries are excluded when judging semantic-model quality
- A separate English-only positive/no-result cohort is checked in; Arabic and mixed coverage comes from the primary corpus
- The qint8 filename is x86-oriented even though the inspected graph uses standard ONNX ops; Android acceptance requires the exact file to load and query on RMX3636

ObjectBox stores L2-normalized 384-d vectors on a new HNSW property. The previous 768-d property is retained as `legacyEmbedding768` with its original UID so upgrades clear and reindex instead of reusing an incompatible HNSW definition.

### 2.6 Model lifecycle

Create a single `ModelCoordinator` abstraction. It serializes access to native inference and prevents accidental simultaneous heavy workloads.

- Extraction flow: release the embedding session if needed, initialize PaddleOCR, recognize ordered text, release OCR resources when memory pressure requires it, load Qwen2.5-0.5B, generate one JSON draft, close the Qwen session, validate in Dart, then open Review/Edit.
- Save/search flow: load multilingual-e5-small, generate the document/query vector, and retain it while the search experience is active. Release it on app background or after an idle timeout.
- Never initialize multiple extraction engines concurrently.
- Do not assume every runtime must always be unloaded between calls. Measure OCR/Qwen/embedding load cost and memory on real devices, then choose separate idle policies.
- On low-memory devices, do not retain PaddleOCR, Qwen, and E5 concurrently. Release Qwen before loading E5.

The model coordinator must expose states suitable for Cubit: unavailable, notInstalled, downloading, verifying, ready, loading, running, cancelling, failed, and disposed.

### 2.7 Local database

Use **ObjectBox for Dart/Flutter 5.3.2** for the MVP.

Reasons:

- Mature Flutter packages from a verified publisher.
- Android and iOS support.
- ACID local persistence.
- Native HNSW approximate nearest-neighbor index.
- Direct cosine, Euclidean, geographic, dot-product, and non-normalized dot-product distance options.
- `nearestNeighborsF32()` plus `findWithScores()` in Dart.
- Vector conditions can be combined with ordinary metadata conditions.
- Core database and Dart bindings are Apache 2.0/free; paid Data Sync is not required and must not be included.

Configuration:

- `@Property(type: PropertyType.floatVector)` on the invoice embedding.
- `@HnswIndex(dimensions: 384, distanceType: VectorDistanceType.cosine)`.
- Keep the retired 768-d vector property (`legacyEmbedding768`) and its original UID until every installed store has migrated; never reuse that UID for a different HNSW dimensionality.
- Store only L2-normalized vectors created by the chosen embedding model/version.
- Treat ObjectBox scores as distances; lower is closer.
- Start with default HNSW values. Tune `neighborsPerNode` or `indexingSearchCount` only after measuring recall and latency with a realistic local dataset.

Limitations and safeguards:

- ObjectBox is native and does not provide the required Flutter Web data path; web is not an MVP target.
- Vector pre-filter behavior and recall with selective metadata filters must be tested rather than assumed.
- Keep `objectbox-model.json` under source control once generated; never recreate it casually.
- The core database is free, while Sync and professional support are separate commercial offerings.
- Do not claim app-level database encryption. The MVP relies on the mobile OS app sandbox and device/file encryption. If product requirements demand a separate database key, evaluate it as a later security phase because ObjectBox's public core offering does not establish that requirement for this plan.

Alternatives considered:

- `sqlite-vec`: portable and improving, but its direct Flutter wrapper remains prerelease/unverified and ANN support is still evolving. It adds native extension packaging work without a clear MVP advantage.
- SQLite `Vec1`: official SQLite ANN work now supports L2/cosine and ARM NEON, but it remains a separately compiled extension with no equally mature first-party Flutter integration.
- `sqflite` alone: no built-in vector index and was intentionally not selected.

ObjectBox is the simpler and more reliable mobile choice for this MVP.

## 3. MVVM and feature organization

Do not introduce Clean Architecture layer names. Each feature owns its view, ViewModel/Cubit, models used by that view, repository interfaces/implementations where needed, and feature widgets.

Planned structure:

```text
lib/
  main.dart
  core/
    constants/
    routing/
    theme/
    shared_pref/
    database/
    ai/
    storage/
    utils/
    widgets/
  features/
    home/
      models/
      repositories/
      view_models/
      views/
      widgets/
    invoice_capture/
      models/
      repositories/
      view_models/
      views/
      widgets/
    invoice_details/
      models/
      repositories/
      view_models/
      views/
      widgets/
    search/
      models/
      repositories/
      view_models/
      views/
      widgets/
    settings/
      models/
      repositories/
      view_models/
      views/
      widgets/
```

Rules:

- A ViewModel is implemented as a Cubit and owns presentation state and orchestration for its view.
- Widgets do not access ObjectBox, SharedPreferences, file storage, or AI engines directly.
- Repositories hide persistence and data-source details but are kept feature-local unless genuinely shared.
- Native/runtime wrappers live under `core/ai`; they expose app-owned interfaces so packages can be replaced.
- ObjectBox initialization and generated files live under `core/database`.
- Shared visual components live in `core/widgets`; feature-specific components stay with their feature.
- All user-facing text uses Flutter localization resources, with Arabic as the default locale and RTL verified.

## 4. MVP screens and navigation

Use seven routed experiences rather than nine independent screens:

1. **Home** — recent invoices, summary, search entry, and primary add action.
2. **Image Preview** — confirms the selected/captured image and allows retake/reselect.
3. **Processing** — visual progress for preparation, model loading, extraction, and validation.
4. **Invoice Review/Edit** — mandatory editable draft before save.
5. **Invoice Details** — saved invoice image, fields, products, and edit/delete actions.
6. **Search** — query input, routing/loading state, filters, and results in one screen.
7. **Settings** — language/theme, model installation/status/storage, and privacy information.

“Add Invoice” is a bottom sheet or dialog offering Camera and Gallery; it does not need its own route. Search Results are part of the Search route so query state, filters, and results stay together.

Use `go_router` with a shell for Home, Search, and Settings. Push Preview, Processing, Review, and Details above the shell. Route arguments contain IDs or small immutable draft references, not large image bytes.

## 5. Local MVP data model

### InvoiceEntity

```text
id: int (ObjectBox ID)
merchant: String?
merchantNormalized: String?
documentType: String?
purchaseDate: DateTime?
totalMinor: int?
currencyCode: String?
warrantyMonths: int?
warrantyEndDate: DateTime? (derived from reviewed values)
invoiceNumber: String?
rawExtractedText: String?
searchableText: String
keywordText: String
imagePath: String
thumbnailPath: String?
sourceType: String (camera/gallery)
embedding: List<double>?
embeddingModelId: String?
embeddingDimensions: int?
searchTextSchemaVersion: int
extractionModelId: String?
createdAt: DateTime
updatedAt: DateTime
reviewedAt: DateTime
```

### InvoiceItemEntity

```text
id: int (ObjectBox ID)
invoice relation / invoiceId
name: String
nameNormalized: String
quantity: double?
unitPriceMinor: int?
lineTotalMinor: int?
```

### Settings

Store only simple preferences through `SharedPreferencesAsync` or `SharedPreferencesWithCache`, selected after Phase 1 verification:

```text
locale
themeMode
preferredInferenceBackend
modelInstallAcknowledged
lastSelectedCaptureSource
```

Do not store invoices, model paths relied upon as critical truth, embeddings, or download integrity state only in SharedPreferences. The package explicitly does not guarantee critical writes.

### Why there is no separate Embedding entity

The MVP creates one searchable representation and one vector per invoice. Keeping the vector on `InvoiceEntity` simplifies atomic save/update/delete and metadata-filtered vector search. Introduce a separate embedding/chunk entity only if later versions support multiple chunks, multiple embedding models simultaneously, or item-level retrieval.

## 6. Searchable text design

Keep three distinct representations:

1. Display values: exactly what the user reviewed.
2. `keywordText`: deterministic normalized tokens for exact/substring search.
3. `searchableText`: short, natural, retrieval-oriented text sent to multilingual-e5-small.

Suggested Arabic-first document representation:

```text
نوع المستند: فاتورة شراء
المتجر: بي تك
رقم الفاتورة: 12345
المنتجات: Samsung Galaxy A56
الفئة: هاتف محمول
الإجمالي: 24999 جنيه مصري EGP
تاريخ الشراء: 2026-08-09، أغسطس 2026
الضمان: 12 شهر، ينتهي في أغسطس 2027
```

Include:

- Reviewed document type.
- Reviewed merchant.
- Reviewed invoice/reference number when present.
- Reviewed product names and quantities.
- A product category only when user-confirmed or produced by a controlled local dictionary.
- Total in normalized digits, ISO currency code, and a stable local Arabic currency label.
- ISO purchase date plus Arabic month/year wording.
- Reviewed warranty duration and derived end month/year.

Exclude:

- Raw OCR noise and repeated headers/footers.
- Full terms and conditions.
- Unreviewed model guesses.
- Arbitrary model-generated aliases.
- Payment-card data, unrelated phone numbers, and sensitive identifiers that do not improve retrieval.
- Duplicate line items and repeated totals.

Normalization must be deterministic and separately unit-tested:

- Unicode normalization (NFKC where safe).
- Remove Arabic tatweel and optional diacritics for the search-only copy.
- Normalize Alef variants (`أ`, `إ`, `آ` -> `ا`) and Arabic Yeh variants for the search-only copy.
- Convert Arabic-Indic and Persian digits to ASCII digits.
- Lowercase Latin text.
- Collapse whitespace and normalize punctuation.
- Preserve the original reviewed display value untouched.
- Add controlled synonyms such as `EGP`, `جنيه`, and `جنيه مصري` from local dictionaries.
- Do not transliterate or translate product/merchant names automatically.

Every change to the representation increments `searchTextSchemaVersion` and queues affected invoices for local re-embedding.

## 7. Search strategy

The search coordinator chooses among structured filtering, keyword search, semantic search, or a limited combination. It must not embed every query by default.

### Structured metadata filtering

Use deterministic parsing for high-confidence patterns:

- Numeric comparisons: `فوق 10000 جنيه`, `أقل من 500`.
- Date/month/year: `في أغسطس 2026`, `السنة اللي فاتت` using a locally defined date range.
- Warranty range: `ضمانها هيخلص الشهر ده` using `warrantyEndDate`.
- Currency and document-type filters.

Do not build a general Arabic natural-language parser for the MVP. Implement a small, tested grammar for amount operators, date ranges, currency tokens, and warranty phrases. If parsing is ambiguous, fall back to semantic search instead of silently applying the wrong filter.

### Keyword search

Use for:

- Product model/SKU-like queries such as `Samsung A56`.
- Invoice numbers.
- Merchant names.
- Quoted or short exact terms.

Query normalized indexed fields and `keywordText`. For the expected MVP dataset, deterministic ObjectBox string conditions are sufficient; a separate full-text engine is unnecessary.

### Semantic search

Use for descriptive or conversational intent:

- `الفاتورة بتاعة الموبايل اللي اشتريته من فترة`.
- Mixed Arabic/English descriptions without an exact identifier.
- Queries where meaning matters more than literal tokens.

Generate the query vector with the official retrieval-query prompt and search the invoice HNSW index using cosine distance.

### Limited hybrid behavior

- Apply confidently parsed metadata constraints together with vector search when the query contains both a filter and descriptive intent.
- For ordinary semantic queries, retrieve top semantic candidates and optionally boost exact merchant/product token matches using a simple documented score rule.
- Do not introduce an LLM query router, reranker, or complicated rank fusion in the MVP.
- Log the selected route locally in debug builds only so routing behavior can be tested without collecting user queries remotely.

## 8. Package plan

Versions below are the verified 2026-08-09 snapshot. Re-resolve and pin the tested set in `pubspec.lock` during implementation.

| Purpose | Package | Snapshot | Decision |
|---|---|---:|---|
| Routing | `go_router` | 17.4.0 installed | Keep |
| Simple settings | `shared_preferences` | 2.5.5 installed | Keep; settings only |
| Cubit/UI state | `flutter_bloc` | 9.1.1 | Add in Phase 1 |
| Value equality | `equatable` | 2.1.0 | Add if states are handwritten |
| Localization | `flutter_localizations` | Flutter SDK | Add in Phase 2 |
| Image capture/import | `image_picker` | 1.2.3 | Add in Phase 6 |
| App document paths | `path_provider` | 2.1.6 | Add directly in Phase 5/6 |
| Object persistence/vector search | `objectbox` | 5.3.2 | Add in Phase 5 |
| ObjectBox native Flutter libs | `objectbox_flutter_libs` | 5.3.2 | Add in Phase 5 |
| ObjectBox generation | `objectbox_generator` | 5.3.2 | Dev dependency, Phase 5 |
| Code generation runner | `build_runner` | compatible stable | Dev dependency, Phase 5 |
| PaddleOCR runtime bridge | native Paddle Lite + PP-OCRv5 artifacts | pin after device spike | Add only in Phase 7 |
| Qwen/LiteRT-LM Flutter core | `flutter_gemma` | 1.4.0 snapshot | Verify Qwen2.5-0.5B, then pin in Phase 7 |
| Qwen LiteRT-LM engine | `flutter_gemma_litertlm` | 1.3.1 snapshot | Verify Qwen2.5-0.5B, then pin in Phase 7 |
| Embedding backend | native ORT Android + Extensions MethodChannel | 1.21.1 / 0.13.0 | Selected for Phase 8; no `flutter_gemma_embeddings` |
| Cubit tests | `bloc_test` | compatible stable | Dev dependency when ViewModels begin |

Explicitly avoid for the first MVP:

- `camera`: `image_picker` already covers basic capture and gallery import. Add `camera` only if a custom live document camera is later justified.
- `permission_handler`: do not add until a permission cannot be handled by the selected official plugin/platform configuration.
- `sqflite`: not required.
- `flutter_gemma_mediapipe`: not required for the selected Qwen LiteRT-LM text model.
- `flutter_gemma_rag_sqlite` and `flutter_gemma_rag_qdrant`: ObjectBox is the single persistence/vector system.
- Firebase model downloading: forbidden by product scope.
- Direct multimodal/VLM extraction: not selected for the MVP; PaddleOCR is the required image-reading stage.

## 9. Model distribution and offline behavior

Bundle only the small, redistribution-approved PaddleOCR assets when APK/AAB measurements remain acceptable. Do not bundle the approximately 521 MB Qwen model or the approximately 118 MB E5 encoder weights in the base application; install them through the verified offline-model workflow to keep app updates small and allow atomic model replacement. The E5 tokenizer preprocessing graph may be bundled because it contains no encoder weights.

Recommended workflow:

1. Ship the UI/data application without the large Qwen/embedding weights; include OCR weights only after license and package-size approval.
2. Present a clear “Install offline AI” setup in Settings or first-use capture.
3. Show exact download size, expected installed size, Wi-Fi recommendation, privacy explanation, and license notice.
4. Download from a controlled static HTTPS model host/CDN—not a remote inference service and not Firebase.
5. Download each large model to a temporary file with foreground-service support where required.
6. Verify expected length and SHA-256 checksum before activation.
7. Atomically move the verified model into app-managed storage.
8. Keep the previous verified model until the replacement is complete, subject to free-space checks.
9. Verify the bundled/downloaded OCR artifact set and dictionary versions through the same model manifest.
10. After installation, prove OCR, extraction, and search in airplane mode.

Do not ship a developer Hugging Face token inside the app. Production distribution must confirm the applicable PaddleOCR/Paddle Lite, Qwen, LiteRT-LM, and EmbeddingGemma terms and use an approved hosting method. An optional “import model from local file” flow can later support fully offline/sideloaded deployments, but is not required for the consumer MVP.

Model manifest fields:

```text
modelId
displayName
runtime
fileName
version/revision
byteLength
sha256
minimumAppVersion
capabilities
installedAt
```

The manifest and verified installation record are critical state and must be stored in app-managed files/ObjectBox, not only SharedPreferences.

## 10. Background work and threading

- LiteRT-LM inference already performs native threaded work. Use its asynchronous/streaming API; do not wrap the entire FFI call in a Dart isolate without evidence.
- Never initialize or run the model synchronously on the Flutter UI isolate. Official Kotlin guidance warns initialization can take up to about ten seconds.
- Use `image_picker` size controls initially. If custom decode/resize becomes necessary, use a native image API or a dedicated isolate for Dart CPU work.
- JSON/tool-argument parsing is small; keep it on the main isolate unless profiling says otherwise.
- Searchable-text normalization is cheap per invoice; use an isolate only for bulk re-indexing.
- Use ObjectBox async APIs/transactions for database work. Profile vector queries before adding another isolate.
- Serialize extraction and embedding operations through `ModelCoordinator` to avoid thermal and memory spikes.
- Cancel cleanly when the user leaves Processing, and release resources when the app receives memory pressure or moves to the background.

## 11. Phased implementation plan

### Phase 1 — Foundation verification and dependency baseline

**Evidence-backed status (2026-08-10): implemented; deterministic baseline verified.**

- `flutter pub get`, code generation, formatting, and `flutter analyze` are part of the current release-QA matrix. Android is arm64-only with application ID `com.tarek.wara2a`; native debug unit checks and fresh arm64 APK builds are also exercised.
- The Flutter/AGP dependency set still emits future built-in-Kotlin migration warnings for `flutter_gemma`, `objectbox_flutter_libs`, and `ppocr-sdk`. They are warnings, not a current compile or test failure.

**Goal**

Lock the existing MVVM/feature-based conventions, verify build targets, and install only the foundational UI/state packages.

**Features**

- App bootstrap and dependency composition plan.
- Cubit conventions and base state patterns.
- Platform capability matrix displayed only in developer diagnostics.
- No AI functionality.

**Technical work**

- Record the current Flutter 3.44.4 / Dart 3.12.2 baseline.
- Confirm Android namespace/application ID and replace `com.example` before release work.
- Confirm practical Android min/target SDK after dependency resolution.
- Plan iOS deployment target 16.0, but do not claim iOS AI support yet.
- Add `flutter_bloc`; add `equatable` only if handwritten immutable states use it.
- Keep existing `go_router` and `shared_preferences` versions.
- Define repository and ViewModel naming rules for every feature.
- Add analyzer/test commands to the Definition of Done.
- Create a short architecture decision record for PaddleOCR + Qwen2.5-0.5B, LiteRT-LM, EmbeddingGemma, and ObjectBox.

**Files/modules affected**

- `pubspec.yaml`, `pubspec.lock`
- `lib/main.dart`
- `lib/core/`
- `analysis_options.yaml`
- platform build configuration files
- `test/`

**Dependencies/packages**

- `flutter_bloc`
- optionally `equatable`
- existing `go_router`, `shared_preferences`

**Acceptance criteria**

- Debug Android build succeeds on a physical arm64 device.
- `flutter analyze` and current tests pass.
- No Firebase/Supabase/remote API/auth dependency exists.
- Folder naming is MVVM/feature-based, not Clean Architecture.
- Package lockfile is committed once a Git repository exists.

**Risks / notes**

- The current directory is not a Git repository, so generated database metadata and dependency locks cannot yet be protected by version control.
- Do not install AI packages merely to satisfy this phase; native feasibility belongs to Phase 7.

### Phase 2 — Arabic design system and navigation

**Evidence-backed status (2026-08-10): implemented; physical smoke verified, full widget gate incomplete.**

- RMX3636 smoke evidence confirms Arabic RTL defaults, English LTR after switching language, light/dark switching, and persistence across a relaunch. Home, Search, and Settings opened with accessible labels.
- Preview, Processing, Review, and Details were not physically traversed in this no-model/no-image QA pass. The legacy widget runner still produces no output and times out under current Windows process contention, so it is not counted as passing evidence.

**Goal**

Create the main visual language, RTL behavior, and complete navigation skeleton before business logic.

**Features**

- Arabic default locale and RTL layout.
- Theme, typography, colors, spacing, buttons, cards, form fields, progress, dialogs, and empty/error components.
- Navigation shell for Home, Search, and Settings.
- Routes for Preview, Processing, Review, and Details.

**Technical work**

- Add Flutter localization generation and Arabic/English resource files.
- Define semantic colors and typography; use the existing Wara2a logo asset.
- Configure `go_router`, route names, transitions, back behavior, and unknown-route handling.
- Build responsive layouts for common phone sizes and large text scale.
- Add golden/widget tests for core reusable components and RTL mirroring.

**Files/modules affected**

- `lib/core/theme/`
- `lib/core/constants/`
- `lib/core/routing/`
- `lib/core/widgets/`
- `lib/l10n/`
- `lib/main.dart`

**Dependencies/packages**

- `flutter_localizations` from the Flutter SDK
- `intl` only if required directly by generated localization/date formatting

**Acceptance criteria**

- Every planned route opens using placeholder views.
- Arabic is RTL and English is LTR without manual direction hacks.
- No user-facing hardcoded strings remain in route placeholders/components.
- Text scaling to 200% does not hide primary actions.
- Light/dark themes meet contrast requirements.

**Risks / notes**

- Avoid designing around English widths and then mirroring late.
- Keep extraction progress truthful; do not show fake percentages that the future runtime cannot supply.

### Phase 3 — Home and invoice flow with mock data

**Evidence-backed status (2026-08-10): implemented; non-widget flow tests pass; physical save/review evidence remains limited.**

- Capture, extraction-state, draft mapping, review-save, cancellation, and manual-fallback Cubit tests pass.
- This QA pass did not select a physical camera/gallery image or reach a model-backed Review screen, so the end-to-end device flow is not newly accepted here.

**Goal**

Finish the complete capture-to-details user experience using fake repositories and simulated extraction.

**Features**

- Home recent invoices and empty state.
- Add Invoice camera/gallery source sheet (UI only in this phase).
- Image Preview with a static fixture.
- Processing with simulated named steps.
- Mandatory Invoice Review/Edit form.
- Save simulation and Invoice Details.
- Loading, empty, validation, retry, and fatal-error states.

**Technical work**

- Create immutable `InvoiceDraft` and `InvoiceItemDraft` view models.
- Implement fake invoice repository and fake extraction service with deterministic fixture data.
- Implement Cubits for Home, Capture Flow, Review, and Details.
- Define field validation and money/date presentation rules.
- Ensure Processing cannot navigate directly to a persisted detail without Review confirmation.
- Add fixture invoices in Arabic, English, and mixed text.

**Files/modules affected**

- `lib/features/home/`
- `lib/features/invoice_capture/`
- `lib/features/invoice_details/`
- `test/features/`
- test fixture assets

**Dependencies/packages**

- foundational packages only
- `bloc_test` for Cubits

**Acceptance criteria**

- The entire flow works with no native plugin and no network.
- All draft fields are editable and nullable.
- User cancellation never creates a saved invoice.
- Validation errors are field-specific and Arabic-readable.
- At least one UI test covers happy path, extraction failure, manual-entry fallback, and back/cancel behavior.

**Risks / notes**

- Do not let fake progress states dictate unsupported native percentages.
- Keep draft models independent from future ObjectBox annotations.

### Phase 4 — Search UI with mock routing and results

**Evidence-backed status (2026-08-10): implemented; deterministic routing verified.**

- The Search route opens on RMX3636. Search Cubit and intent-router tests cover exact identifiers, Arabic/Persian digits, amount/date/warranty filters, and safe semantic routing.
- Device data was intentionally empty, so real saved-invoice result navigation was not physically demonstrated in this QA pass.

**Goal**

Finalize the search experience before embeddings or vector storage exist.

**Features**

- Search input and recent query UI stored locally only if the privacy design allows it.
- Mock semantic, keyword, and structured-filter results.
- Filter chips for amount/date/document type.
- Result cards, empty state, error state, and model-not-installed state.
- Navigation to Invoice Details.

**Technical work**

- Define `SearchIntent`, `SearchRequest`, `SearchResult`, and `SearchRouteType` models.
- Create fake router/repository with deterministic scenarios for the examples in this plan.
- Implement one Search Cubit state machine: idle, editing, routing, loading, success, empty, and error.
- Design result explanation labels such as exact match, semantic match, or filtered result without exposing raw similarity numbers.

**Files/modules affected**

- `lib/features/search/`
- `test/features/search/`
- localization resources

**Dependencies/packages**

- no AI/database dependency yet

**Acceptance criteria**

- The three example query classes visibly take the intended mock route.
- Results update without navigation to a separate results screen.
- Search is usable with keyboard, screen reader, RTL, and large text.
- No query is sent over a network.

**Risks / notes**

- UI wording must not imply semantic certainty.
- Do not expose a similarity threshold until retrieval evaluation establishes one.

### Phase 5 — ObjectBox local data layer

**Evidence-backed status (2026-08-10): implemented; host persistence checks pass; device persistence gate remains open.**

- ObjectBox CRUD, atomic rollback, migration, stale-embedding, HNSW, and managed-file deletion tests pass after installing ObjectBox's official local test DLL. That DLL and the accompanying import library remain ignored from Git.
- An invoice create/edit/delete/restart sequence was not run on the physical device during this pass.

**Goal**

Replace fake persistence with reliable local invoice storage while keeping mocked extraction/search behavior.

**Features**

- Create/read/update/delete invoices and items.
- Persistent image paths and metadata.
- Empty vector field reserved for later embeddings.
- Reactive recent-invoice/home updates.
- SharedPreferences-backed settings repository.

**Technical work**

- Add stable ObjectBox runtime and generator packages.
- Define `InvoiceEntity` and `InvoiceItemEntity` with minimal indexes.
- Create the 768-dimension cosine HNSW property.
- Generate and preserve `objectbox.g.dart` and `objectbox-model.json`.
- Implement mapping between domain/view models and entities.
- Use transactions so invoice and items save atomically.
- Implement delete semantics for entity, items, image, thumbnail, and embedding.
- Create migration/version policies for searchable text and embedding model changes.
- Implement settings through a modern SharedPreferences API, not the legacy singleton by default.

**Files/modules affected**

- `lib/core/database/`
- `lib/core/shared_pref/`
- feature repositories under Home, Capture, Details, and Search
- `objectbox-model.json`
- persistence tests

**Dependencies/packages**

- `objectbox`
- `objectbox_flutter_libs`
- `path_provider`
- dev: `objectbox_generator`, `build_runner`

**Acceptance criteria**

- Data survives force-stop and restart in airplane mode.
- Invoice plus items save atomically.
- Editing reviewed fields updates normalized/searchable text and marks embedding stale.
- Deleting an invoice removes its owned files and records without orphan data.
- Migration test opens a previous test schema safely.
- SharedPreferences contains no invoice or embedding payload.

**Risks / notes**

- ObjectBox model UIDs are migration-critical.
- Desktop unit tests may need the native ObjectBox test library; mobile integration tests remain required.

### Phase 6 — Real camera/gallery input and local image management

**Evidence-backed status (2026-08-10): implemented in code and unit-tested; physical acceptance remains incomplete.**

- Image validation and capture Cubit tests cover unsupported/corrupt/oversized images, cancelled reselect, lost-data recovery, and cleanup of replaced drafts.
- Camera and gallery selection plus durable-image restart behavior were not physically retested in this pass; do not treat the unit suite as substitute device evidence.

**Goal**

Replace the fake image source with reliable local capture/import while leaving extraction mocked.

**Features**

- Camera capture through system camera UI.
- Gallery import.
- Preview, retake/reselect, and invalid-image handling.
- Durable app-owned image copy and optional thumbnail.
- Lost-data recovery on Android where supported by `image_picker`.

**Technical work**

- Add `image_picker`.
- Configure required iOS usage descriptions and Android platform behavior.
- Copy picker results from temporary/cache storage into the application documents directory.
- Validate MIME/decodability, dimensions, and file-size limits.
- Preserve original aspect ratio and orientation.
- Start with picker resize/quality controls; add custom preprocessing only after extraction evaluation.
- Implement cleanup for cancelled drafts and failed saves.

**Files/modules affected**

- `lib/features/invoice_capture/repositories/`
- `lib/core/storage/`
- Android manifest/configuration
- iOS `Info.plist`
- integration tests

**Dependencies/packages**

- `image_picker`
- direct `path_provider`

**Acceptance criteria**

- Camera and gallery both work on a physical Android device in airplane mode.
- A selected image remains available after process restart once committed to a draft/save flow.
- Cancelled/failed flows do not leak permanent files.
- Very large, corrupt, and unsupported images produce recoverable UI errors.

**Risks / notes**

- Images returned by the camera picker initially live in cache and must be moved.
- A custom document scanner is explicitly deferred.

### Phase 7 — PaddleOCR + Qwen on-device extraction

**Goal**

Replace simulated extraction with the validated local two-stage OCR-and-text pipeline on Android.

**Evidence-backed status (2026-08-10): implemented; release acceptance incomplete.**

- The durable image -> PaddleOCR -> Qwen text-only -> strict Dart validation -> editable Review -> explicit ObjectBox save workflow is connected on Android. Settings provides exact-size/hash model install, status, cancellation, and removal; model weights are not bundled in Git or the APK.
- The Qwen LiteRT-LM artifact gap is resolved for Android through a documented fallback to pinned MediaPipe LLM Inference `0.10.27` and the official revision-pinned Q8 `.task`. Current LiteRT-LM conversion remains a future migration because no official pinned hosted `.litertlm` with a reproducible URL/size/hash was available for this exact model.
- One physical realme RMX3636 (Android 15, arm64, about 8 GB RAM) proved model verification, 14-line bilingual OCR in 2,797 ms, and direct Qwen load plus strict JSON generation (352 ms initialization, 6,604 ms generation). Peak sampled PSS/RSS were 1,689,818/1,782,784 kB; thermal details are recorded in `docs/phase7-local-ai-runtime.md`.
- The original invoice-shaped run did not pass acceptance: Qwen emitted a 1,034-character unterminated/repetitive object, then the one repair attempt timed out at 60 seconds. A targeted follow-up tried two smaller prompt/schema variants on the same verified 1,280-context artifact: one produced 966 characters of invalid JSON and could not fit its repair prompt beside an experimental 512-token reserve; the final variant timed out at 60 seconds before a complete object was available. Both returned the intended editable manual fallback without saving, and the unsuccessful prompt/reserve experiments were reverted.
- The exact MediaPipe `0.10.27` API exposes an engine-wide `setMaxTokens`, session sampling controls, token counting, cancellation, and an opaque constraint handle, but no public per-generation token limit or public constraint-handle creator. The debug harness now records measured prompt tokens and requires typed non-manual `InvoiceDraft`/`ReviewRouteArgs` fields after a future success; no physical invoice run reached those assertions. Further 0.5B retries stopped after the bounded failures. The 50-invoice corpus, 4/6 GB device matrix, airplane-mode product install, and ten sequential runs remain open release gates.
- Current release QA also fixed the arm64 release R8 configuration for the pinned MediaPipe artifact and corrected an ABI-display bug that falsely called a real arm64 device unsupported for EmbeddingGemma. The fresh QA device had no verified Phase 7 models, so no new full invoice-shaped extraction result replaces the unresolved manual-fallback evidence above.

**Features**

- OCR and Qwen model installation/status/removal UI.
- Device capability and free-space checks.
- Local Arabic/English OCR with cancel/retry.
- Strict Qwen JSON output to `InvoiceDraft`.
- Manual fallback when extraction cannot complete.

**Technical work**

- Integrate Paddle Lite/PP-OCRv5 behind the app-owned `OcrEngine` native bridge and pin the detector, Arabic recognizer, English/Latin recognizer, dictionaries, and runtime revisions proven by a device spike.
- Add `flutter_gemma` and `flutter_gemma_litertlm` only after their pinned versions prove that the LiteRT Qwen2.5-0.5B artifact loads and generates correctly on the target devices.
- Implement `OcrEngine`, `InvoiceTextInterpreter`, `InvoiceDraftValidator`, and `ModelCoordinator` app interfaces.
- Preprocess the image without destroying small Arabic glyph details; measure rotation correction, resize, contrast, blur, and glare handling against the evaluation corpus.
- Preserve OCR lines, bounding boxes, script, and confidence; route confident crops once and uncertain/mixed crops through both recognizers only when required.
- Normalize Arabic-Indic/Persian digits, whitespace, bidi artifacts, currency forms, and OCR punctuation without altering the raw OCR evidence.
- Serialize the OCR evidence into a bounded prompt that preserves reading order and useful coordinates.
- Define the strict JSON schema and typed Dart validator. Qwen receives OCR evidence only, never the invoice image.
- Limit Qwen output tokens and session history; each invoice is a new session and thinking is disabled unless evaluation proves a material benefit.
- Add deterministic parsing for obvious amounts, dates, currencies, and arithmetic consistency. Use Qwen for semantic mapping and ambiguous layouts rather than replacing validation rules.
- Add one JSON repair attempt, cancellation, per-stage timeout, progress states, and resource disposal.
- Persist only the user-reviewed draft, never raw tool output directly.
- Build a redacted/synthetic evaluation set of at least 50 invoices: Arabic, English, mixed, thermal receipts, printed A4 invoices, skew, glare, and low contrast.
- Measure OCR character/word accuracy separately from end-to-end field accuracy so failures can be assigned to image reading, semantic mapping, or validation.

**Files/modules affected**

- `lib/core/ai/ocr/`
- `lib/core/ai/extraction/`
- `lib/features/settings/`
- `lib/features/invoice_capture/repositories/`
- Capture/Processing/Review Cubits
- Android native build configuration
- model manifest assets/config
- AI integration/evaluation tests

**Dependencies/packages**

- native PaddleOCR Android ONNX bridge, ONNX Runtime Android `1.21.1`, official OpenCV Android `4.13.0`, and revision-pinned PP-OCRv5 mobile artifacts
- MediaPipe LLM Inference `0.10.27` for the verified Android Qwen `.task` fallback; keep the app-owned interpreter boundary for later LiteRT-LM migration
- no `flutter_gemma`/`flutter_gemma_litertlm` until a compatible `.litertlm` artifact and wrapper pass the release gates
- no direct vision-language package; PaddleOCR remains the only image-reading stage

**Acceptance criteria**

- OCR and Qwen extraction succeed with networking disabled after model installation.
- Arabic, English, and mixed-script invoices preserve readable OCR text and correct reading order at the approved quality threshold.
- 100% of accepted outputs parse into the schema; invalid output becomes a retry/manual state, never a crash.
- Missing/obscured fields remain null in the evaluation set at the agreed rate.
- No invoice is saved without opening Review and receiving explicit confirmation.
- Release gates are defined per field (total/date/currency exact match, merchant normalized match, product item F1) and approved against the evaluation corpus.
- OCR time, Qwen time, total warm/cold latency, peak memory, model-load time, battery delta, and thermal behavior are recorded on at least a 4 GB and a 6 GB Android device.
- Ten sequential runs do not crash, leak sessions, or progressively slow down beyond the agreed tolerance.

**Risks / notes**

- Arabic language coverage does not prove Arabic invoice accuracy; both OCR and field extraction need Wara2a-specific evaluation.
- PaddleOCR has no assumed mature Flutter abstraction in this plan; the native bridge and runtime packaging are explicit implementation risks.
- Community LiteRT-LM Flutter integration can regress rapidly; pin versions and keep the app-owned Qwen interface narrow.
- If Qwen JSON reliability fails, improve prompting/constrained decoding and deterministic parsing before considering a larger model. Do not silently replace the two-stage architecture.

### Phase 8 — multilingual-e5-small integration

**Evidence-backed status (2026-08-10): Dart/native bridge and ObjectBox 384-d migration are implemented; Android physical inference remains open.**

- Host benchmark selected MIT `intfloat/multilingual-e5-small` qint8 and rejected MiniLM. EmbeddingGemma and `flutter_gemma_embeddings` were removed from the embedding path.
- The app owns an immutable E5 artifact contract, MethodChannel engine, ORT Extensions SentencePiece tokenizer asset, secure atomic installer, 384-d validation, query/document prefixes, cancellation/unload lifecycle, Settings install/status UI, and a dual-property ObjectBox migration that preserves invoice rows while clearing legacy 768-d vectors for reindex.
- Production semantic search remains `SemanticSearchCalibration.blocked()` / `MultilingualE5Calibration.production` until Android arm64 offline evidence approves a threshold bound to the pinned model ID/hash/schema/corpus.
- No claim of device load, airplane-mode embedding, release calibration, or APK-size acceptance is valid until RMX3636 records those results.

**Goal**

Generate and persist one local retrieval embedding from each reviewed invoice.

**Features**

- Deterministic searchable-text generation.
- Local embedding model installation/status.
- Document embedding after review/save.
- Re-embedding queue for edited or version-stale invoices.

**Technical work**

- Install the pinned E5 ONNX encoder through the verified offline installer; keep weights out of Git.
- Bundle only the tokenizer preprocessing graph under `android/app/src/main/assets/embedding/`.
- Implement `EmbeddingEngine` behind the Android MethodChannel ORT + Extensions runtime.
- Format documents/queries with the official E5 prefixes plus Wara2a retrieval formatting.
- Validate output length 384, finite values, and L2 normalization.
- Migrate ObjectBox from the legacy 768-d HNSW property to a new 384-d property without UID reuse.
- If embedding fails after invoice confirmation, save the invoice with a visible “search indexing pending” state and retry locally; never lose reviewed data.

**Dependencies/packages**

- `com.microsoft.onnxruntime:onnxruntime-android:1.21.1`
- `com.microsoft.onnxruntime:onnxruntime-extensions-android:0.13.0`
- no `flutter_gemma_embeddings`

**Acceptance criteria**

- Embedding generation works in airplane mode after model installation.
- Every vector has exactly 384 finite, normalized values.
- Searchable text is deterministic for the same reviewed data.
- Editing a searchable field marks/rebuilds the vector; editing a non-searchable UI field does not.
- Extraction and embedding models are not simultaneously retained on the minimum-memory device unless measurements approve it.
- Legacy 768-d stores open, preserve invoice/item rows, clear incompatible vectors, and queue reindex.

### Phase 9 — Local semantic search

**Evidence-backed status (2026-08-10): implementation and host benchmarks present; Android release gate blocked.**

- The repository enforces `MultilingualE5Calibration.production` / `SemanticSearchCalibration.blocked()` by default and returns no fabricated semantic result.
- Host E5 semantic/hybrid Recall@1/3/5 and MRR are 1.0; MiniLM is rejected. Structured labels are excluded from semantic-quality judgment. English-only positives/no-result cases are checked in separately.
- No Android-approved threshold, device latency/RAM/thermal record, or airplane-mode semantic run exists yet. Semantic search must remain disabled in production until that evidence binds to the pinned model ID/hash/schema/corpus.

**Goal**

Replace mock semantic results with multilingual-e5-small plus ObjectBox cosine HNSW retrieval.

**Features**

- Arabic/English/mixed natural query embedding.
- Top-K local vector retrieval.
- Similarity-distance threshold and empty results.
- Search result navigation to Invoice Details.

**Technical work**

- Format queries using E5 `query: ` plus Wara2a retrieval formatting.
- Query `nearestNeighborsF32()` and retrieve ordered results with distances.
- Start with top 20 candidates and tune top-K/threshold from evaluation, not intuition.
- Handle invoices with pending/missing embeddings.
- Approve a threshold only against labeled ar/en/mixed queries with honest no-result cases, bound to the pinned E5 contract.

**Acceptance criteria**

- Semantic search works in airplane mode after model installation.
- Target Recall@5 >= 0.90 on the approved evaluation set, or the release is blocked/pivoted.
- Warm query embedding plus database retrieval meets the 750 ms p95 planning target on the reference device, or the UX/loading target is revised transparently.
- No-result behavior is based on an evaluated threshold.
- Search never returns an invoice whose image/data was deleted.

### Phase 10 — Keyword, structured, and limited hybrid search

**Evidence-backed status (2026-08-10): exact/structured functionality verified; semantic branch intentionally gated.**

- ObjectBox search, Search Cubit, and intent-router tests pass for exact model/merchant terms and Arabic/Persian numeric, date, currency, document-type, and warranty filters.
- Hybrid behavior falls back only to explicit identifiers while semantic calibration is blocked; conversational claims are not silently presented as exact matches.

**Goal**

Route queries to the simplest correct search mechanism and combine filters only when confidence is high.

**Features**

- Exact merchant/product/invoice-number keyword search.
- Amount, date, currency, document-type, and warranty filters.
- Semantic search with optional structured constraints.
- User-visible editable filters.

**Technical work**

- Implement deterministic Arabic digit/operator/date normalization.
- Build the small intent router described in Section 7.
- Combine ObjectBox vector and metadata conditions where supported and tested.
- Define a simple keyword boost for semantic candidates; avoid an LLM reranker.
- Add route-level tests for ambiguous and mixed queries.
- Let users clear/change inferred filters before rerunning.

**Files/modules affected**

- `lib/features/search/models/`
- `lib/features/search/repositories/`
- Search Cubit and widgets
- `lib/core/utils/arabic_query_normalization/`
- query parser tests

**Dependencies/packages**

- no new dependency expected

**Acceptance criteria**

- `Samsung A56` uses keyword search.
- `الفواتير فوق 10000 جنيه` uses a numeric metadata filter.
- `الفواتير اللي ضمانها هيخلص الشهر ده` uses a warranty-end date range.
- Conversational descriptive queries use semantic search.
- Mixed filter plus descriptive intent applies both only when parser confidence is high.
- Parser tests cover Arabic-Indic digits, Persian digits, common Egyptian Arabic operators, and ambiguous phrases.

**Risks / notes**

- Egyptian Arabic has many variants; unsupported phrasing should fall back safely.
- Metadata-filtered ANN behavior needs recall testing with selective filters.

### Phase 11 — Performance, lifecycle, storage, and privacy hardening

**Evidence-backed status (2026-08-10): partially implemented; release hardening gates remain open.**

- Secure model-install tests cover HTTPS, exact length/SHA-256 verification, atomic activation, and failed-download non-activation. Source review found no cloud/auth/analytics SDK and no bundled secrets/models.
- The final Android APK includes transitive `background_downloader` permissions (`WAKE_LOCK`, `ACCESS_NETWORK_STATE`, `RECEIVE_BOOT_COMPLETED`, and `FOREGROUND_SERVICE`) in addition to `INTERNET`; no app source schedules an unrelated transfer, but final privacy/permission approval remains required. Airplane-mode product install/relaunch, low storage, lifecycle, thermal, battery, and deletion-recovery acceptance are still open.

**Goal**

Make model installation, repeated inference, memory lifecycle, and local storage safe enough for real devices.

**Features**

- Model download verification and recovery.
- Storage usage and model deletion controls.
- Backend fallback and low-memory behavior.
- Index rebuild progress.
- Clear privacy/offline status.

**Technical work**

- Implement model manifest, SHA-256 verification, atomic activation, and partial-download cleanup.
- Measure CPU/GPU backend stability and choose per-device fallback rules.
- Tune model idle timeouts and release on app lifecycle/memory pressure.
- Measure battery and thermal impact over repeated extraction sessions.
- Downscale images only if evaluation shows equivalent accuracy.
- Add database/image backup exclusion decisions and sensitive logging rules.
- Strip invoice text, images, queries, and model output from production logs/crash payloads.
- Add local “delete all data and models” with explicit confirmation.
- Document OS-level encryption reliance and remaining privacy limitations.

**Files/modules affected**

- `lib/core/ai/model_management/`
- `lib/core/storage/`
- Settings feature
- Android/iOS lifecycle/native configuration
- diagnostics and integration tests

**Dependencies/packages**

- prefer existing cryptography utilities already available transitively only if exposed appropriately; otherwise add a small maintained SHA-256 package after review

**Acceptance criteria**

- Interrupted/corrupt downloads never become active models.
- Airplane-mode relaunch works after installation.
- App background/foreground does not corrupt an active invoice draft.
- Model deletion cannot delete invoice records/images.
- “Delete all local data” removes invoices, vectors, images, settings, and models as documented.
- Production logging contains no invoice content or search query.
- Performance gates pass on the chosen support matrix.

**Risks / notes**

- A model update temporarily needs space for old and new copies.
- GPU drivers differ significantly; stability wins over benchmark speed.

### Phase 12 — Testing, offline validation, and release readiness

**Evidence-backed status (2026-08-10): partial release QA completed; MVP release is blocked.**

- Split non-widget tests, ObjectBox host-native checks, Android native unit tests, and arm64 debug/release build checks are part of the current QA evidence. The physical RMX3636 smoke launch is successful.
- The legacy widget suite remains a no-output timeout under current Windows runner contention. iOS/macOS, 4 GB/6 GB Android coverage, normal on-device model download, airplane-mode end-to-end behavior, 50-invoice extraction accuracy, ten sequential extractions, and real 100-query semantic calibration remain incomplete.
- The current `release` variant deliberately uses Android's debug signing configuration. It is a QA APK, not a production-distributable signed release, until a protected production signing workflow is configured and verified.

**Goal**

Prove the MVP works offline, is recoverable, and meets agreed Arabic extraction/retrieval quality on supported devices.

**Features**

- Complete automated and manual release suite.
- First-run/model-install education.
- Privacy and model-license disclosures.
- Supported-device messaging.

**Technical work**

- Unit tests: normalization, money/date conversion, query parser, schema validation, searchable text, mappings.
- Cubit tests: every loading/success/empty/error/cancel state.
- Widget/golden tests: Arabic RTL, English LTR, large text, dark/light, review validation.
- ObjectBox integration tests: CRUD, transaction rollback, migration, HNSW query, metadata-filtered vector query.
- AI integration tests on physical devices using the approved invoice corpus.
- End-to-end airplane-mode tests from capture through search/details.
- Process-death tests during capture, model download, processing, and save.
- Low-storage, corrupt-model, model-missing, and database-error tests.
- Release Android AAB build and arm64 ABI inspection.
- Provisional iOS release build/testing only on macOS with physical devices.
- Generate final package/model license inventory.

**Files/modules affected**

- `test/`
- `integration_test/`
- platform release/signing configuration
- privacy/license documentation
- CI configuration once Git exists

**Dependencies/packages**

- Flutter test/integration test tooling
- `bloc_test`
- mocking library only if fakes cannot cover the boundary cleanly

**Acceptance criteria**

- Full MVP passes in airplane mode after model installation.
- No network request occurs during capture, inference, save, indexing, or search.
- Extraction and retrieval quality gates are documented with corpus version and device/model versions.
- Analyzer, unit, widget, integration, and release-build checks pass.
- No authentication/cloud/analytics dependency exists.
- User can always correct AI fields before save.
- Known unsupported devices receive a clear message instead of a native crash.
- All third-party and model licenses are included and approved.

**Risks / notes**

- Passing an emulator is not mobile-AI release evidence.
- Do not call iOS complete until a signed physical-device release build passes.

## 12. MVP-wide Definition of Done

**Current status (2026-08-10): not met.** The implemented app is a credible Android-first MVP candidate, but no completion claim is valid until the unverified physical-model, quality, semantic, device-matrix, offline, and Apple-platform gates above are closed.

The MVP is complete only when all of the following are true:

- Camera/gallery invoice input works locally.
- PaddleOCR extracts Arabic/English invoice text and Qwen2.5-0.5B converts it into a validated draft without a network after model installation.
- Every AI result enters a mandatory editable review step.
- Reviewed invoices and images survive restart.
- multilingual-e5-small generates local document/query vectors after explicit offline install.
- ObjectBox persists vectors and returns semantic results locally.
- Keyword and structured examples route without unnecessary embedding.
- Arabic and mixed-language quality passes the project evaluation corpus.
- Supported-device RAM, storage, latency, thermal, and battery behavior are measured.
- No remote service, auth, analytics, or cloud database is required.
- Deletion and error recovery do not leave orphaned sensitive data.
- Completion claims are backed by physical-device, airplane-mode evidence.

## 13. Research sources

- [LiteRT-LM overview and platform/model benchmarks](https://ai.google.dev/edge/litert-lm/overview)
- [LiteRT-LM Flutter API guidance](https://ai.google.dev/edge/litert-lm/flutter)
- [LiteRT-LM repository and API status](https://github.com/google-ai-edge/LiteRT-LM)
- [PaddleOCR PP-OCRv5 text-recognition models](https://www.paddleocr.ai/v3.3.1/en/version3.x/module_usage/text_recognition.html)
- [PaddleOCR PP-OCRv5 multilingual overview](https://www.paddleocr.ai/latest/en/version3.x/algorithm/PP-OCRv5/PP-OCRv5_multi_languages.html)
- [Qwen2.5-0.5B-Instruct model card](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct)
- [Qwen2.5-0.5B LiteRT community artifact](https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct)
- [EmbeddingGemma overview](https://ai.google.dev/gemma/docs/embeddinggemma)
- [EmbeddingGemma model card, dimensions, quantization, and prompts](https://ai.google.dev/gemma/docs/embeddinggemma/model_card)
- [EmbeddingGemma LiteRT artifacts](https://huggingface.co/litert-community/embeddinggemma-300m/tree/main)
- [`flutter_gemma` package](https://pub.dev/packages/flutter_gemma)
- [`flutter_gemma_litertlm` package](https://pub.dev/packages/flutter_gemma_litertlm)
- [`flutter_gemma_embeddings` package](https://pub.dev/packages/flutter_gemma_embeddings)
- [ObjectBox Flutter package](https://pub.dev/packages/objectbox)
- [ObjectBox on-device vector search documentation](https://docs.objectbox.io/on-device-vector-search)
- [ObjectBox Flutter getting started](https://docs.objectbox.io/getting-started)
- [ObjectBox database/Sync pricing distinction](https://objectbox.io/sync-pricing/)
- [SQLite Vec1 documentation](https://sqlite.org/vec1/doc/trunk/doc/vec1.md)
- [`sqlite-vec` repository](https://github.com/asg017/sqlite-vec)
- [`image_picker` package](https://pub.dev/packages/image_picker)
- [`shared_preferences` storage warning and API](https://pub.dev/packages/shared_preferences)
