import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

apply(from = "client_secret_guard.gradle")

// Flutter's `test`/integration_test runner forwards Dart defines as the
// `dart-defines` Gradle property, but does not reliably forward arbitrary
// project properties. Detect the explicit test-only define as well as the
// direct Gradle property. Normal builds have neither, so their IDs are intact.
val decodedDartDefines = providers.gradleProperty("dart-defines").orNull
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
val driveItEnvironment = providers.environmentVariable("DRIVEIT_PLAY_RELEASE").orNull
if (driveItEnvironment != null && driveItEnvironment != "true" && driveItEnvironment != "false") {
    throw GradleException("DRIVEIT_PLAY_RELEASE must be exactly 'true' or 'false'.")
}
val driveItPlayRelease = driveItEnvironment == "true"
val driveItManualDevAcceptance =
    "DRIVEIT_MANUAL_DEV_ACCEPTANCE=true" in decodedDartDefines
val driveItIsolatedTest =
    providers.gradleProperty("driveItIsolatedTest").orNull == "true" ||
        "DRIVEIT_ISOLATED_ANDROID_TEST=true" in decodedDartDefines
val driveItLocalOwnerActivation =
    providers.gradleProperty("driveItLocalOwnerActivation").orNull == "true" ||
        "DRIVEIT_LOCAL_OWNER_ACTIVATION=true" in decodedDartDefines
val flutterTarget = providers.gradleProperty("target").orNull
    ?.replace('\\', '/')
    ?.trimStart('/')
    .orEmpty()
val isAndroidIntegrationTestBuild =
    Regex("(^|/)integration_test/[^/]+\\.dart$").containsMatchIn(flutterTarget)
val isAndroidInstrumentationBuild = gradle.startParameter.taskNames.any {
    it.contains("AndroidTest", ignoreCase = true)
}
val isReleaseAppBundleBuild = gradle.startParameter.taskNames.any {
    it.contains("bundleRelease", ignoreCase = true)
}
val baseApplicationId = "com.example.driveit_project"
val isolatedApplicationId = "$baseApplicationId.isolated_test"
val playApplicationId = "com.osaracx.driveit"
val configuredApplicationId =
    when {
        driveItIsolatedTest -> isolatedApplicationId
        driveItPlayRelease -> playApplicationId
        else -> baseApplicationId
    }
val playKeyStorePath = providers.environmentVariable("DRIVEIT_PLAY_KEYSTORE").orNull
val playKeyAlias = providers.environmentVariable("DRIVEIT_PLAY_KEY_ALIAS").orNull
val playStorePassword = providers.environmentVariable("DRIVEIT_PLAY_STORE_PASSWORD").orNull
val playKeyPassword = providers.environmentVariable("DRIVEIT_PLAY_KEY_PASSWORD").orNull
val playEnabledFeatures = listOf(
    "DRIVEIT_LOCAL_OWNER_ACTIVATION",
    "DRIVEIT_ACCOUNT_SYNC_ENABLED",
    "DRIVEIT_ACCOUNT_DELETE_ENABLED",
    "DRIVEIT_GROUP_DRIVE_ENABLED",
    "DRIVEIT_MANUAL_DEV_ACCEPTANCE",
).filter { name -> decodedDartDefines.any { it == "$name=true" } }
val playSupabaseConfig = decodedDartDefines.filter {
    it.startsWith("SUPABASE_URL=") || it.startsWith("SUPABASE_PUBLISHABLE_KEY=")
}

if (driveItIsolatedTest && driveItLocalOwnerActivation) {
    throw GradleException("Isolated test and local production owner activation cannot be combined.")
}
if (driveItPlayRelease && driveItIsolatedTest) {
    throw GradleException("Play release and isolated Android test configurations cannot be combined.")
}
if (driveItManualDevAcceptance && !driveItIsolatedTest) {
    throw GradleException("Manual DEV acceptance is allowed only in the isolated Android package.")
}
if (driveItManualDevAcceptance && driveItPlayRelease) {
    throw GradleException("Manual DEV acceptance cannot be built as a Play release.")
}
if (driveItPlayRelease && driveItLocalOwnerActivation) {
    throw GradleException("Play release cannot enable the unverified local production owner runtime.")
}
if (driveItPlayRelease && playEnabledFeatures.isNotEmpty()) {
    throw GradleException(
        "Play release refuses unverified feature opt-ins: ${playEnabledFeatures.joinToString()}",
    )
}
if (driveItPlayRelease && playSupabaseConfig.isNotEmpty()) {
    throw GradleException(
        "Play release refuses unverified Supabase configuration; no DEV project may be presented as PROD.",
    )
}
if (driveItPlayRelease && gradle.startParameter.taskNames.any {
        it.contains("Debug", ignoreCase = true) || it.contains("AndroidTest", ignoreCase = true)
    }) {
    throw GradleException("Play release mode may only build the non-test release variant.")
}
if (isReleaseAppBundleBuild && !driveItPlayRelease) {
    throw GradleException(
        "Refusing release AAB without DRIVEIT_PLAY_RELEASE=true and the Play upload signing configuration.",
    )
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
        val expected = when {
            driveItIsolatedTest -> isolatedApplicationId
            driveItPlayRelease -> playApplicationId
            else -> baseApplicationId
        }
        check(configuredApplicationId == expected) {
            "Refusing Android build: applicationId $configuredApplicationId != expected $expected"
        }
        if (isAndroidIntegrationTestBuild) {
            check(configuredApplicationId == isolatedApplicationId) {
                "Refusing Android integration test install: package is not isolated"
            }
        }
        check(flutter.targetSdkVersion == 36) {
            "Refusing Android build: expected targetSdk 36, got ${flutter.targetSdkVersion}"
        }
        check(flutter.versionCode > 0) {
            "Refusing Android build: versionCode must be positive"
        }
        check(flutter.versionName.isNotBlank()) {
            "Refusing Android build: versionName must not be blank"
        }
        logger.lifecycle("Verified Android applicationId: $configuredApplicationId")
        logger.lifecycle("Verified Android targetSdk: ${flutter.targetSdkVersion}")
        logger.lifecycle("Verified Android version: ${flutter.versionName} (${flutter.versionCode})")
    }
}
val verifyPlayReleaseSigning = tasks.register("verifyPlayReleaseSigning") {
    dependsOn(verifyAndroidApplicationId)
    doLast {
        check(driveItPlayRelease) {
            "Refusing Play signing verification unless DRIVEIT_PLAY_RELEASE=true"
        }
        check(configuredApplicationId == playApplicationId) {
            "Refusing Play release: wrong applicationId"
        }
        check(!playKeyStorePath.isNullOrBlank() && file(playKeyStorePath).isFile) {
            "Refusing Play release: DRIVEIT_PLAY_KEYSTORE must point to an existing upload keystore"
        }
        check(!playKeyAlias.isNullOrBlank()) {
            "Refusing Play release: DRIVEIT_PLAY_KEY_ALIAS is required"
        }
        check(!playStorePassword.isNullOrBlank() && !playKeyPassword.isNullOrBlank()) {
            "Refusing Play release: upload keystore passwords must be supplied through the process environment"
        }
        check(android.buildTypes.getByName("release").signingConfig?.name == "playUpload") {
            "Refusing Play release: the release variant must use the upload signing config"
        }
    }
}
tasks.configureEach {
    if (name == "preDebugBuild" || name == "preReleaseBuild") {
        dependsOn(verifyAndroidApplicationId)
        if (name == "preReleaseBuild" && driveItPlayRelease) {
            dependsOn(verifyPlayReleaseSigning)
        }
    }
    if (name == "bundleRelease" && driveItPlayRelease) {
        dependsOn(verifyAndroidApplicationId, verifyPlayReleaseSigning)
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
        applicationId = if (driveItPlayRelease) playApplicationId else baseApplicationId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["driveItIsolatedOwnerRuntime"] = "false"
        manifestPlaceholders["driveItLocalOwnerRuntime"] =
            if (driveItLocalOwnerActivation && !driveItIsolatedTest) "true" else "false"
        manifestPlaceholders["driveItAuthScheme"] = configuredApplicationId.replace('_', '-')
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        testApplicationId = "$configuredApplicationId.test"
    }

    signingConfigs {
        create("playUpload") {
            if (!playKeyStorePath.isNullOrBlank()) {
                storeFile = rootProject.file(playKeyStorePath)
            }
            keyAlias = playKeyAlias
            storePassword = playStorePassword
            keyPassword = playKeyPassword
        }
    }

    buildTypes {
        getByName("debug") {
            if (driveItIsolatedTest) {
                applicationIdSuffix = ".isolated_test"
                manifestPlaceholders["driveItIsolatedOwnerRuntime"] = "true"
            }
        }
        release {
            // Existing development releases retain their behavior. Play builds
            // must use a real external upload key and are guarded above.
            signingConfig = if (driveItPlayRelease) {
                signingConfigs.getByName("playUpload")
            } else {
                signingConfigs.getByName("debug")
            }
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
