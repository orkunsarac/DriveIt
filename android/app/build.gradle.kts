import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Flutter's `test`/integration_test runner forwards Dart defines as the
// `dart-defines` Gradle property, but does not reliably forward arbitrary
// project properties. Detect the explicit test-only define as well as the
// direct Gradle property. Normal builds have neither, so their IDs are intact.
val isolatedTestDartDefines = providers.gradleProperty("dart-defines").orNull
    ?.split(',')
    ?.mapNotNull { encoded ->
        runCatching {
            String(
                Base64.getDecoder().decode(encoded),
                Charsets.UTF_8,
            )
        }.getOrNull()
    }
    .orEmpty()
val driveItIsolatedTest =
    providers.gradleProperty("driveItIsolatedTest").orNull == "true" ||
        "DRIVEIT_ISOLATED_ANDROID_TEST=true" in isolatedTestDartDefines

android {
    namespace = "com.example.driveit_project"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.driveit_project"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["driveItIsolatedOwnerRuntime"] = "false"
    }

    buildTypes {
        getByName("debug") {
            if (driveItIsolatedTest) {
                applicationIdSuffix = ".isolated_test"
            }
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            if (driveItIsolatedTest) {
                applicationIdSuffix = ".isolated_test"
                manifestPlaceholders["driveItIsolatedOwnerRuntime"] = "true"
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    if (driveItIsolatedTest) {
        // Flutter's generated plugin registrant references integration_test
        // even for an isolated release test target. Keep its Android bridge
        // confined to builds that also receive the isolated package suffix.
        add("releaseImplementation", project(":integration_test"))
    }
}
