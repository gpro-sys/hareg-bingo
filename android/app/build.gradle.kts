import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// WaveMart-style signing: android/key.properties (committed) points at the
// release keystore, so CI checks out everything it needs to sign releases
// without any GitHub secrets.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.hareg.bingo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.hareg.bingo"
        // The reference app requires shared_preferences/qr_flutter plugins
        // that need modern APIs; keep 24+ to match the original minSdk.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 64-bit only, matching the CI build target (android-arm64).
        // Without this, dependency .so blobs (e.g. androidx datastore)
        // get packaged for every ABI Flutter doesn't restrict.
        ndk {
            abiFilters += setOf("arm64-v8a")
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Keep release builds slim like the reference pipeline.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    // Hard strip non-arm64 shared objects at packaging time. ndk.abiFilters
    // alone leaves tiny dependency bombs (libdatastore_shared_counter.so)
    // behind for every ABI, enabling installs that would crash on launch.
    packaging {
        jniLibs {
            excludes += setOf(
                "lib/armeabi-v7a/**",
                "lib/x86/**",
                "lib/x86_64/**",
            )
        }
    }
}

flutter {
    source = "../.."
}
