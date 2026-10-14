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
val driveItLocalOwnerActivation =
    providers.gradleProperty("driveItLocalOwnerActivation").orNull == "true" ||
        "DRIVEIT_LOCAL_OWNER_ACTIVATION=true" in isolatedTestDartDefines
val flutterTarget = providers.gradleProperty("target").orNull
    ?.replace('\\', '/')
    ?.trimStart('/')
    .orEmpty()
val isAndroidIntegrationTestBuild =
    Regex("(^|/)integration_test/[^/]+\\.dart$").containsMatchIn(flutterTarget)
val isAndroidInstrumentationBuild = gradle.startParameter.taskNames.any {
    it.contains("AndroidTest", ignoreCase = true)
}
val baseApplicationId = "com.example.driveit_project"
val isolatedApplicationId = "$baseApplicationId.isolated_test"
val configuredApplicationId =
    if (driveItIsolatedTest) isolatedApplicationId else baseApplicationId

if (driveItIsolatedTest && driveItLocalOwnerActivation) {
    throw GradleException("Isolated test and local production owner activation cannot be combined.")
}
if (driveItLocalOwnerActivation && gradle.startParameter.taskNames.any {
        it.contains("Debug", ignoreCase = true)
    }) {
    throw GradleException("Local production owner activation is release-only.")
}

// Flutter's integration_test runner installs the APK immediately after its
// Gradle assemble task. Refuse to build a test target unless the package is
// isolated, so a missing define can never fall back to the user's app ID.
if (isAndroidIntegrationTestBuild && !driveItIsolatedTest) {
    throw GradleException(
        "Refusing Android integration_test target '$flutterTarget': " +
            "set DRIVEIT_ISOLATED_ANDROID_TEST=true; test APKs may not use $baseApplicationId.",
    )
}
if (isAndroidIntegrationTestBuild && configuredApplicationId != isolatedApplicationId) {
    throw GradleException(
        "Refusing Android integration_test target with applicationId $configuredApplicationId; " +
            "expected $isolatedApplicationId.",
    )
}
if (isAndroidInstrumentationBuild &&
    (!isAndroidIntegrationTestBuild || !driveItIsolatedTest ||
        configuredApplicationId != isolatedApplicationId)) {
    throw GradleException(
        "Refusing Android instrumentation build without an isolated integration_test target.",
    )
}

val verifyAndroidApplicationId = tasks.register("verifyAndroidApplicationId") {
    doLast {
        val expected = if (driveItIsolatedTest) isolatedApplicationId else baseApplicationId
        check(configuredApplicationId == expected) {
            "Refusing Android build: applicationId $configuredApplicationId != expected $expected"
        }
        if (isAndroidIntegrationTestBuild) {
            check(configuredApplicationId == isolatedApplicationId) {
                "Refusing Android integration test install: package is not isolated"
            }
        }
        logger.lifecycle("Verified Android applicationId: $configuredApplicationId")
    }
}
tasks.configureEach {
    if (name == "preDebugBuild" || name == "preReleaseBuild") {
        dependsOn(verifyAndroidApplicationId)
    }
}

android {
    namespace = "com.example.driveit_project"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    if (driveItIsolatedTest) {
        // The native FlutterTestRunner must target the actual release AOT app;
        // normal builds retain AGP's default debug instrumentation variant.
        testBuildType = "release"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = baseApplicationId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["driveItIsolatedOwnerRuntime"] = "false"
        manifestPlaceholders["driveItLocalOwnerRuntime"] =
            if (driveItLocalOwnerActivation && !driveItIsolatedTest) "true" else "false"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        testApplicationId = "$configuredApplicationId.test"
    }

    buildTypes {
        getByName("debug") {
            if (driveItIsolatedTest) {
                applicationIdSuffix = ".isolated_test"
                manifestPlaceholders["driveItIsolatedOwnerRuntime"] = "true"
            }
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            if (driveItIsolatedTest) {
                applicationIdSuffix = ".isolated_test"
                manifestPlaceholders["driveItIsolatedOwnerRuntime"] = "true"
                // The release AndroidTest APK must retain AndroidJUnitRunner
                // and the FlutterTestRunner test class; this affects only the
                // isolated test release build, not a normal production release.
                isMinifyEnabled = false
                isShrinkResources = false
                testProguardFiles("proguard-phase5-release-acceptance.pro")
            }
        }
    }
}

// The generated registrant includes integration_test because Flutter marks it
// as a dev plugin. Keep that test plugin in debug and isolated acceptance APKs
// only. A regular release gets a no-op registration bridge from src/release.
if (!driveItIsolatedTest) {
    android.sourceSets.getByName("release").java.srcDir("src/release/java")
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
    // Match the versions selected by Flutter 3.44.8's integration_test
    // release dependency constraints (runner 1.3.0 / rules 1.2.0 / JUnit 4.12).
    androidTestImplementation("androidx.test:runner:1.3.0")
    androidTestImplementation("androidx.test:rules:1.2.0")
    androidTestImplementation("junit:junit:4.12")
    if (driveItIsolatedTest) {
        add("debugImplementation", project(":integration_test"))
        add("releaseImplementation", project(":integration_test"))
        add("androidTestImplementation", project(":integration_test"))
    } else {
        add("debugImplementation", project(":integration_test"))
    }
}
