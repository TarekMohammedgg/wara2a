import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.tarek.wara2a"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.tarek.wara2a"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // multilingual-e5-small ORT + Extensions Android packaging and the
        // existing MediaPipe Qwen fallback both require API 30+.
        minSdk = 30
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters += "arm64-v8a"
        }
    }

    buildTypes {
        release {
            // Release artifacts must use a publisher-controlled signing key.
            // Configure a release signing config before distributing an APK.
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    packaging {
        jniLibs {
            excludes += setOf(
                "**/armeabi-v7a/*.so",
                "**/x86/*.so",
                "**/x86_64/*.so",
            )
        }
    }
}

dependencies {
    implementation(project(":ppocr-sdk"))
    implementation("com.google.mediapipe:tasks-genai:0.10.27")
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.21.1")
    implementation("com.microsoft.onnxruntime:onnxruntime-extensions-android:0.13.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
