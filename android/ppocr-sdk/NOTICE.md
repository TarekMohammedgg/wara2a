# Vendored PaddleOCR Android source

The Kotlin sources in this module are a focused adaptation of the official
PaddleOCR `deploy/ppocr-android/ppocr-sdk` implementation at commit
`2661c7c0ef5c613e8f93c6e93b2e052399f0f854`.

Upstream project: https://github.com/PaddlePaddle/PaddleOCR

Upstream files adapted here include `ORTSessionManager.kt`,
`DetectionEngine.kt`, `RecognitionEngine.kt`, `ModelConfig.kt`,
`DetPreprocessor.kt`, `RecPreprocessor.kt`, `DBPostProcessor.kt`,
`PolygonUnclip.kt`, `QuadGeometry.kt`, `QuadTextCrop.kt`, `BoxSorter.kt`,
`CTCDecoder.kt`, `BaseRecLabelDecode.pred_reverse`, and their small
model/utility types. The adaptations load
app-managed filesystem paths, keep independent Arabic and Latin recognizer
sessions, expose cancellation checkpoints between non-cancellable ONNX calls,
and produce Wara2a's app-owned evidence shape.

PaddleOCR is licensed under the Apache License 2.0. The adapted source files
retain the upstream copyright and license header. No model weights are copied
or bundled by this module.

Runtime dependencies are resolved from Maven rather than vendored:

- ONNX Runtime Android 1.21.1 (`com.microsoft.onnxruntime:onnxruntime-android`),
  MIT License.
- Official OpenCV Android AAR 4.13.0 (`org.opencv:opencv`); OpenCV 4.13.0
  is Apache License 2.0.
- Kotlin coroutines Android 1.9.0, Apache License 2.0.

The external detector and recognizer ONNX/YML artifacts remain separately
installed app data and require their own revision, checksum, and license
records in Wara2a's model manifest.
