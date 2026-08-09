# Phase 7 local extraction runtime decision

Research snapshot: 2026-08-09

This decision keeps Wara2a's extraction pipeline fully local and preserves two
independent app-owned boundaries:

```text
invoice image
  -> OcrEngine (PP-OCRv5 detector + Arabic/Latin recognizers)
  -> ordered OcrEvidence (text, box, script, confidence)
  -> InvoiceTextInterpreter (Qwen2.5-0.5B-Instruct, text only)
  -> strict JSON parser and typed InvoiceDraftValidator
  -> mandatory manual review result
```

No image is sent to Qwen and no network inference fallback exists.

## Runtime decisions

### Android OCR: enabled at the bridge level

The native bridge vendors the official PaddleOCR Android ONNX SDK source from
commit `2661c7c0ef5c613e8f93c6e93b2e052399f0f854`. It pins ONNX Runtime Android
`1.21.1`, QuickBird OpenCV `4.5.3`, Kotlin coroutines Android `1.9.0`, Android
`minSdk 26`, and the initial `arm64-v8a` application ABI.

The upstream SDK supports only one recognizer and sorts same-row boxes
left-to-right. Wara2a adapts it to a shared detector plus Arabic and Latin
recognizers, returns an app-owned payload, restores the PaddleOCR Arabic
`pred_reverse` behavior, and applies RTL-aware reading order. Script is an
app-derived property; PaddleOCR does not return a script-classification field.
Recognizer channel order is read from the pinned YAML instead of assuming that
the upstream Android demo's unconditional BGR-to-RGB conversion matches every
exported model.

ONNX Runtime inference calls are synchronous. Cancellation is therefore
cooperative: the bridge checks cancellation between native calls and suppresses
any late result, but it does not claim that an in-flight ORT call was interrupted.

The bridge is executable only after all six OCR files below have been installed
and verified in app support storage. The repository does not bundle or download
weights.

Primary sources:

- [PaddleOCR Android deployment guide](https://www.paddleocr.ai/main/en/version3.x/inference_deployment/cross_platform/android_deployment.html)
- [Pinned official Android SDK source](https://github.com/PaddlePaddle/PaddleOCR/tree/2661c7c0ef5c613e8f93c6e93b2e052399f0f854/deploy/ppocr-android)
- [PaddleOCR license](https://github.com/PaddlePaddle/PaddleOCR/blob/2661c7c0ef5c613e8f93c6e93b2e052399f0f854/LICENSE)

### Qwen text interpretation: capability-gated

The selected runtime remains LiteRT-LM, but no production adapter or Flutter
runtime dependency is enabled in this commit. The verified LiteRT Community
repository revision contains `.task` and `.tflite` artifacts, while current
LiteRT-LM and `flutter_gemma_litertlm` require a `.litertlm` unified container.
Renaming a `.task` file would not convert its format.

The app therefore exposes an `incompatibleArtifact` capability and can still
return OCR evidence in a manual-review-ready draft. Tests use an interpreter
fake only to exercise prompt, parsing, validation, one-repair, timeout, and
fallback behavior; there is no fake production inference implementation.

Qualification requires:

1. Pin upstream `Qwen/Qwen2.5-0.5B-Instruct` and export it on Linux, WSL, or
   macOS with official `litert-torch==0.9.3` to a real `.litertlm` file.
2. Inspect and hash the generated container, then smoke-test it with
   `litert-lm==0.15.0` using the CPU backend.
3. Verify container compatibility with the exact Flutter wrapper runtime. The
   current stable wrapper embeds LiteRT-LM `0.14.0`, for which no public
   cross-version container compatibility guarantee was found.
4. Run Arabic, English, and mixed invoice fixtures, cancellation, disposal,
   memory, latency, and ten sequential extractions on physical Android arm64
   devices before enabling the adapter.
5. Audit third-party redistribution notices for any Flutter native bundle
   before release.

Primary sources:

- [LiteRT-LM overview](https://developers.google.com/edge/litert-lm/overview)
- [LiteRT-LM Android guide](https://developers.google.com/edge/litert-lm/android)
- [LiteRT-LM model-file builder](https://developers.google.com/edge/litert-lm/file_builder)
- [LiteRT-LM 0.15.0 release](https://github.com/google-ai-edge/LiteRT-LM/releases/tag/v0.15.0)
- [Official LiteRT Torch GenAI conversion](https://developers.google.com/edge/litert/conversion/pytorch/genai)
- [Current LiteRT Community Qwen repository](https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/tree/6c237a59eedeb06a821b21f0a59b03d346ac8bc3)
- [Upstream Qwen2.5-0.5B-Instruct](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct/tree/7ae557604adf67be50417f59c2c2f167def9a775)

### iOS: explicitly unsupported for Phase 7 inference

PaddleOCR now has an official iOS ONNX demo, but it is application/demo source,
not a qualified Flutter SDK. Its single-recognizer, Arabic decoding, and reading
order behavior still require the Wara2a adaptations, and no signed physical
device run was performed here. Official LiteRT-LM Swift support is also marked
Early Preview. Dart parsing, validation, and UI remain portable, while the OCR
capability returns `unsupportedPlatform` on iOS.

Primary sources:

- [Pinned PaddleOCR iOS deployment guide](https://github.com/PaddlePaddle/PaddleOCR/blob/2661c7c0ef5c613e8f93c6e93b2e052399f0f854/docs/version3.x/inference_deployment/cross_platform/ios_deployment.en.md)
- [Pinned PaddleOCR iOS demo](https://github.com/PaddlePaddle/PaddleOCR/tree/2661c7c0ef5c613e8f93c6e93b2e052399f0f854/deploy/ios_demo)
- [LiteRT-LM Swift guide](https://developers.google.com/edge/litert-lm/swift)

## Pinned OCR artifacts

All files are official PaddlePaddle Hugging Face artifacts licensed under
Apache-2.0. The app manifest is the executable source of truth for byte lengths,
SHA-256 checksums, source URLs, and revisions.

The six-file OCR download is 20,881,373 bytes (about 19.9 MiB), before runtime
libraries and app packaging.

| Artifact | Revision | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| PP-OCRv5 mobile detector ONNX | `e6f4fa85f00e168c862bc462aebca69eef9b3d3d` | 4,826,518 | `a431985659dc921974177a95adcfbb90fd9e51989a5e04d70d0b75f597b6e61d` |
| Detector `inference.yml` | same | 903 | `98069072e1b6b37d727fd9d9f11725faa46d6ea0de012f2ed26caea011c37699` |
| Arabic PP-OCRv5 mobile recognizer ONNX | `14aaedcd75825982689ecf5cd64ab33ee083215a` | 7,998,947 | `799113ebf267fbe742deb99eb36e8d42c9ddc5291ceacf92add41b4d52a59110` |
| Arabic `inference.yml` | same | 6,165 | `21368419e6c016c31db55d316d59e11c128e1913e6e6fe10287084710043d3a6` |
| Latin PP-OCRv5 mobile recognizer ONNX | `89d3a50e2c27e2e7cceeab0e944c25c807d5db4f` | 8,042,023 | `7888113072263cb471b93f66dd5e2ad70548dc526fa1ace760d0d973dd121498` |
| Latin `inference.yml` | same | 6,817 | `0bbe984570f597af3638e50bdf2e8276f3ab26a61966096538b3b0d1849f5c84` |

Install each file at:

```text
<application-support>/models/phase7/<modelId>/<fileName>
```

`ModelFileVerifier` checks length and SHA-256 before a set becomes ready. Model
download, atomic activation/removal, foreground-service behavior, and free-space
UX are intentionally not implemented in this change.

## Current Qwen artifact recorded as non-installable

For auditability, the manifest records the current Q8 community `.task` file at
revision `6c237a59eedeb06a821b21f0a59b03d346ac8bc3`: 546,660,344 bytes, SHA-256
`e608953f169aeb1bd7b9155fec2559825e08453fc209b84eda3a781ed0452fd2`,
Apache-2.0. Its `installable` flag is `false` because it is a MediaPipe task
container, not the required LiteRT-LM container.

Runtime notices must retain PaddleOCR/model Apache-2.0 attribution, ONNX Runtime
MIT plus its third-party notices, OpenCV Apache-2.0, and the applicable
QuickBird packaging notices. Qwen and LiteRT-LM are Apache-2.0; the deferred
Flutter wrappers are MIT.

## Validation and remaining release gates

The repository can validate the Dart coordinator/parser/validator using
synthetic fixtures and can compile the Android bridge without model files.
Neither result proves OCR quality or Qwen inference. A real image path is also
not produced by the current presentation-only capture screens; camera/gallery
capture is outside this change's scope. Consequently there is no app-level or
physical-device end-to-end extraction claim.

The 2026-08-09 Windows build pass completed `:ppocr-sdk:testDebugUnitTest`
(7 tests), `:app:compileDebugKotlin`, `:app:assembleDebug`, and
`flutter build apk --debug --target-platform android-arm64`. The resulting
debug APK was 288,471,512 bytes and archive inspection found only
`arm64-v8a`. This size includes debug/runtime packaging but no OCR or Qwen
weights. The build emits an AGP 9 built-in-Kotlin migration warning for plugin
modules; it is not a current compile failure but must be resolved before a
future Flutter version makes that migration mandatory.

Release remains blocked on a qualified Qwen `.litertlm`, approved model hosting
and installation UX, physical-device OCR/Qwen evaluation, memory/latency and
ten-run evidence, signed iOS qualification if iOS support is desired, and an
explicit user-confirmed Review/Edit save path.
