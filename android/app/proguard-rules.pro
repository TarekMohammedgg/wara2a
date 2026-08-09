# MediaPipe Tasks GenAI 0.10.27 retains compile-time-only AutoValue and
# protobuf metadata references. AGP generates these four rules when R8
# analyzes the pinned artifact; keeping them explicit makes the arm64 release
# build reproducible without masking unrelated missing classes.
-dontwarn com.google.auto.value.AutoValue
-dontwarn com.google.auto.value.AutoValue$Builder
-dontwarn com.google.protobuf.Internal$ProtoNonnullApi
-dontwarn com.google.protobuf.ProtoPresenceBits
