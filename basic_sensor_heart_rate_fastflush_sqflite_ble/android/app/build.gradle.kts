plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.flutfy.basic_sensor_heart_rate_interval_sqflite_ble"
    // sqflite_android minta di-compile dengan SDK 36 (compileSdk hanya soal
    // waktu compile dan backward compatible — aman dinaikkan).
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.flutfy.basic_sensor_heart_rate_fastflush_ble"
        // Galaxy Watch 4 (Wear OS) minimal API 30; target API 34.
        // Catatan: targetSdk 35 (Android 15) men-deprecate BODY_SENSORS sehingga
        // dialog izin tidak muncul — gunakan 34 agar izin sensor tetap berfungsi.
        minSdk = 30
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
