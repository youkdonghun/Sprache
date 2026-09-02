plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningEnvironment =
    mapOf(
        "SPRACHE_ANDROID_KEYSTORE_PATH" to System.getenv("SPRACHE_ANDROID_KEYSTORE_PATH"),
        "SPRACHE_ANDROID_KEYSTORE_PASSWORD" to System.getenv("SPRACHE_ANDROID_KEYSTORE_PASSWORD"),
        "SPRACHE_ANDROID_KEY_ALIAS" to System.getenv("SPRACHE_ANDROID_KEY_ALIAS"),
        "SPRACHE_ANDROID_KEY_PASSWORD" to System.getenv("SPRACHE_ANDROID_KEY_PASSWORD"),
    )
val suppliedReleaseSigningValues =
    releaseSigningEnvironment.filterValues { !it.isNullOrBlank() }
require(
    suppliedReleaseSigningValues.isEmpty() ||
        suppliedReleaseSigningValues.size == releaseSigningEnvironment.size,
) {
    val missing =
        releaseSigningEnvironment
            .filterValues { it.isNullOrBlank() }
            .keys
            .sorted()
            .joinToString()
    "Android release signing is only partially configured. Missing: $missing"
}
val hasReleaseSigning = suppliedReleaseSigningValues.size == releaseSigningEnvironment.size

android {
    namespace = "com.youkdonghun.sprache"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Stable application ID used by the Android OAuth client configuration.
        applicationId = "com.youkdonghun.sprache"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("spracheRelease") {
                storeFile = file(releaseSigningEnvironment.getValue("SPRACHE_ANDROID_KEYSTORE_PATH")!!)
                storePassword =
                    releaseSigningEnvironment.getValue("SPRACHE_ANDROID_KEYSTORE_PASSWORD")
                keyAlias = releaseSigningEnvironment.getValue("SPRACHE_ANDROID_KEY_ALIAS")
                keyPassword = releaseSigningEnvironment.getValue("SPRACHE_ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Local validation remains installable with the debug key. Publishable
            // builds inject all four SPRACHE_ANDROID_* values outside Git.
            signingConfig =
                if (hasReleaseSigning) {
                    signingConfigs.getByName("spracheRelease")
                } else {
                    signingConfigs.getByName("debug")
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.documentfile:documentfile:1.0.1")
    implementation("com.google.android.gms:play-services-auth:21.6.0")
}
