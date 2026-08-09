# Phase 7 local extraction runtime decision

Research and device-evidence snapshot: 2026-08-10

Status: the Android production workflow is implemented, but Phase 7 release
acceptance is not complete. A physical arm64 device proved real bilingual OCR
and real Qwen generation. The final invoice-shaped run failed strict JSON
validation and safely opened the manual-review path; it did not produce an
accepted extracted draft.

```text
durable captured/imported image
  -> PaddleOCR detector + Arabic/Latin recognizers
  -> ordered OcrEvidence (text, boxes, script, confidence)
  -> Qwen2.5-0.5B-Instruct (OCR text only)
  -> strict JSON boundary + Dart parser/typed validator
  -> editable Review screen
  -> explicit user save to ObjectBox
```

Qwen never receives the image. There is no cloud or network inference path.
`INTERNET` is used only after an explicit offline-model installation action.

## Android runtime decision

### OCR

The app owns a narrow Flutter/Android OCR boundary adapted from the official
PaddleOCR Android ONNX source at commit
`2661c7c0ef5c613e8f93c6e93b2e052399f0f854`. It uses ONNX Runtime Android
`1.21.1`, Kotlin coroutines `1.9.0`, and the official OpenCV Android Maven AAR
`org.opencv:opencv:4.13.0` on the app's arm64-only Android build.

The previous QuickBird OpenCV 4.5.3 AAR contained the expected arm64 library,
but a physical load failed exactly with:

```text
dlopen failed: cannot locate symbol "__sfp_handle_exceptions"
referenced by .../lib/arm64-v8a/libopencv_java4.so
```

That was an obsolete OpenCV binary failure, not a missing filename or a
packaged `libc++_shared.so` winner. Replacing it with the maintained official
4.13.0 AAR made the same physical OCR path run. The cached AAR measured
121,695,690 bytes with SHA-256
`a8c9b0929d8d6367bb476320a1f36587db2b57ea18d8f7521ce509514903ca04`.
OpenCV 4.13.0 and PaddleOCR are Apache-2.0; ONNX Runtime is MIT.

The bridge uses one detector plus independent Arabic and Latin recognizers,
preserves boxes/confidence/raw evidence, restores Arabic `pred_reverse`
behavior, and applies RTL-aware reading order. ONNX calls are synchronous, so
cancellation is cooperative between calls and late results are suppressed; an
in-flight ONNX call is not claimed to be interrupted.

Primary sources:

- [PaddleOCR Android deployment](https://www.paddleocr.ai/main/en/version3.x/inference_deployment/cross_platform/android_deployment.html)
- [Pinned PaddleOCR Android source](https://github.com/PaddlePaddle/PaddleOCR/tree/2661c7c0ef5c613e8f93c6e93b2e052399f0f854/deploy/ppocr-android)
- [Official OpenCV Android Maven guidance](https://docs.opencv.org/4.13.0/d5/df8/tutorial_dev_with_OCV_on_Android.html)
- [OpenCV Maven artifact](https://central.sonatype.com/artifact/org.opencv/opencv/4.13.0)

### Qwen

Current LiteRT-LM uses the unified `.litertlm` container. Its official file
builder can import/convert supported Hugging Face models, so conversion is not
described as impossible. However, the current LiteRT Community repository for
this exact Qwen revision publishes `.task` and `.tflite`, not a pinned hosted
`.litertlm` with reproducible production URL, byte length, and SHA-256. A
locally generated conversion would not satisfy Wara2a's installer provenance
contract without a separately controlled, licensed artifact release.

The verified Android fallback is therefore Google's on-device MediaPipe LLM
Inference `com.google.mediapipe:tasks-genai:0.10.27`, using the published Q8
`.task` artifact on CPU. MediaPipe marks this API maintenance-only and advises
migration to LiteRT-LM. The app keeps its own `InvoiceTextInterpreter`
boundary so that migration does not affect Cubits, validation, or Review.

Each invoice uses a fresh deterministic session (`topK=1`, temperature 0,
seed 0), the official Qwen chat template, a 1,280-token artifact context, and
bounded prompts. Streaming output is stopped at the first balanced top-level
JSON object. Leading prose/markdown remains invalid, and Dart still rejects
unknown keys, wrong types, unsupported evidence, inconsistent arithmetic, and
malformed JSON. One repair attempt is allowed before manual review.

Primary sources:

- [LiteRT-LM overview](https://developers.google.com/edge/litert-lm/overview)
- [LiteRT-LM Android guide](https://developers.google.com/edge/litert-lm/android)
- [LiteRT-LM model-file builder](https://developers.google.com/edge/litert-lm/file_builder)
- [MediaPipe LLM Inference for Android](https://developers.google.com/edge/mediapipe/solutions/genai/llm_inference/android)
- [Pinned LiteRT Community Qwen repository](https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/tree/6c237a59eedeb06a821b21f0a59b03d346ac8bc3)
- [Pinned upstream Qwen model](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct/tree/7ae557604adf67be50417f59c2c2f167def9a775)

### Platform gate

Android 10+ arm64 is implemented. iOS and non-arm64 targets return truthful
unsupported capability states; no signed iOS physical inference was run.

## Reproducible model installation

No model weights are committed to Git or bundled in the APK. Settings exposes
install, progress, cancellation, verification status, retry, and exact removal.
All files live in app-private support storage under `models/phase7`.

The installer:

1. accepts only pinned HTTPS URLs and rejects HTTPS-to-non-HTTPS redirects;
2. checks available storage before downloading;
3. writes to a `.part` file with connection/idle timeouts and cancellation;
4. rejects an unexpected `Content-Length`, received length, or SHA-256;
5. activates only a verified file using same-directory rename, with a
   `.previous` rollback copy during replacement;
6. writes an installation record only after all seven required artifacts pass;
7. gates OCR/Qwen capability on a fresh byte-length and SHA-256 inspection.

The exact required set is 567,541,717 bytes (541.3 MiB):

| Artifact | Revision | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| PP-OCRv5 detector ONNX | `e6f4fa85f00e168c862bc462aebca69eef9b3d3d` | 4,826,518 | `a431985659dc921974177a95adcfbb90fd9e51989a5e04d70d0b75f597b6e61d` |
| Detector YAML | same | 903 | `98069072e1b6b37d727fd9d9f11725faa46d6ea0de012f2ed26caea011c37699` |
| Arabic recognizer ONNX | `14aaedcd75825982689ecf5cd64ab33ee083215a` | 7,998,947 | `799113ebf267fbe742deb99eb36e8d42c9ddc5291ceacf92add41b4d52a59110` |
| Arabic YAML | same | 6,165 | `21368419e6c016c31db55d316d59e11c128e1913e6e6fe10287084710043d3a6` |
| Latin recognizer ONNX | `89d3a50e2c27e2e7cceeab0e944c25c807d5db4f` | 8,042,023 | `7888113072263cb471b93f66dd5e2ad70548dc526fa1ace760d0d973dd121498` |
| Latin YAML | same | 6,817 | `0bbe984570f597af3638e50bdf2e8276f3ab26a61966096538b3b0d1849f5c84` |
| Qwen Q8 `.task` | `6c237a59eedeb06a821b21f0a59b03d346ac8bc3` | 546,660,344 | `e608953f169aeb1bd7b9155fec2559825e08453fc209b84eda3a781ed0452fd2` |

All seven source URLs are exact revision-pinned values in
`assets/models/phase7_model_manifest.json`. The OCR models and Qwen model are
Apache-2.0. The Qwen URL is:

```text
https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/resolve/6c237a59eedeb06a821b21f0a59b03d346ac8bc3/Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task
```

## Physical Android evidence

Device: realme RMX3636, Android 15/API 35, arm64-v8a, 7,875,748 kB reported
RAM. Serial is retained in the engineering log, not in application telemetry.

The opt-in test generated a durable 1080x1600 bilingual invoice containing:
`AL NOOR MARKET`, `متجر النور`, `TAX INVOICE / فاتورة ضريبية`, invoice number
12345, date 2026-08-10, two English product rows, totals in English and Arabic,
and `Thank you / شكراً`.

The device could not resolve the Hugging Face host during the run. The product
installer correctly failed with `modelNotInstalled` at `model-download` and
activated zero unverified bytes. For runtime qualification only, engineering
downloaded the same seven pinned URLs on the host, verified every length/hash,
sideloaded them into the test package, and then ran the production inspector.
That inspector reverified all 567,541,717 bytes in 23,419 ms. This proves the
inspector and offline runtime, not successful device-network downloading.

Final bounded invoice run after the strict streaming boundary:

- OCR completed in 2,797 ms with 14 ordered evidence lines: 3 classified
  Arabic, 8 Latin, and 3 in other script categories. Per-line recognized text
  was not logged, so the fixture text above must not be misreported as exact
  OCR transcription.
- The overall run lasted 127,400 ms. Qwen's initial invoice response was 1,034
  characters and never closed a top-level JSON object. Dart reported
  `invalidJson` at `$` with `Invalid JSON: Unterminated string`.
- The one repair attempt then exceeded its 60-second stage timeout. The result
  was `manualFallback=true`, stage `interpretation-repair`; no model output was
  accepted or saved. The editable Review path retained the durable image and
  raw OCR evidence.
- A separate minimal Qwen probe on the exact same installed artifact initialized
  in 352 ms and generated a 183-byte parseable JSON object in 6,604 ms, proving
  physical model load/generation but not invoice-schema quality.
- An earlier run exposed a complete JSON object followed by generated trailing
  text (752 characters, `Unexpected character`). The native balanced-object
  boundary fixes that real framing defect; the final unterminated/repetitive
  product output is a remaining 0.5B model-quality/prompt gate, not a parser
  crash.

Memory sampling across a combined physical run captured 95 samples: peak total
PSS 1,689,818 kB and peak total RSS 1,782,784 kB. During inference, thermal
status was 1 with CPU/GPU 58.097 C, NPU 57.791 C, skin 44.733 C, and battery
36.8 C at 100%. The post-run sample remained status 1 but cooled to CPU/GPU
43.314 C, NPU 43.161 C, skin 39.944 C, and battery 36.9 C at 100%. These are
single-run engineering readings, not p95 or battery-consumption claims.

## Final host verification

On 2026-08-10, `flutter analyze` completed with no issues. Explicit non-widget
test splits passed 21 AI runtime/contract tests, 8 capture/review/settings tests,
and 10 ObjectBox/storage tests. Android
`:app:testDebugUnitTest :ppocr-sdk:testDebugUnitTest` passed, including the
strict streaming JSON boundary tests. The exact widget runner was not repeated
after multiple no-output timeouts were established as environment contention.

`flutter build apk --debug --target-platform android-arm64` produced an
arm64-only debug APK of 191,304,089 bytes with SHA-256
`e26a9ae4882ae31d2415c539e9b4a57757337efa5e74cbed57cc52d38a41d413`.
It contains the runtime libraries but no external model files. Gradle reports
the existing future AGP built-in-Kotlin migration warning for
`objectbox_flutter_libs` and `ppocr-sdk`; it is not a current build failure.

## Remaining Phase 7 release gates

- Make the exact 0.5B model reliably close and satisfy the production invoice
  schema on the approved 50-invoice redacted/synthetic corpus, or record a new
  architecture decision. Manual fallback is operational meanwhile.
- Prove the device downloader on a network that can reach every pinned host.
- Run airplane-mode acceptance after a normal product install.
- Complete ten sequential extractions and latency/memory/thermal gates on the
  required 4 GB and 6 GB tiers; only one approximately 8 GB device was tested.
- Record OCR and field-level accuracy separately on the approved corpus.
- Qualify signed iOS inference before enabling iOS capability.
- Retry the widget suite after the known Windows runner contention is cleared;
  exact widget invocations repeatedly produced no test output, while split
  non-widget suites passed.
