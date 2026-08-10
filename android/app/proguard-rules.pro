# MediaPipe Tasks GenAI 0.10.27 retains compile-time-only AutoValue and
# protobuf metadata references. AGP generates these four rules when R8
# analyzes the pinned artifact; keeping them explicit makes the arm64 release
# build reproducible without masking unrelated missing classes.
-dontwarn com.google.auto.value.AutoValue
-dontwarn com.google.auto.value.AutoValue$Builder
-dontwarn com.google.protobuf.Internal$ProtoNonnullApi
-dontwarn com.google.protobuf.ProtoPresenceBits

# Both ONNX Runtime artifacts load their JNI entry points and custom-op package
# through named Java classes. Keep that boundary stable in optimized releases.
-keep class ai.onnxruntime.** { *; }
-keep class ai.onnxruntime.extensions.** { *; }
