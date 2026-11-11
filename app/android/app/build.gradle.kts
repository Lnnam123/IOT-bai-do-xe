plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.project_24ct_lenhatnam"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.project_24ct_lenhatnam"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
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
}

// Tự động sao chép và đổi tên file APK theo phiên bản trong code (ví dụ: baidoxe_V1.0.apk)
tasks.register("taoFileApkTheoPhienBan") {
    doLast {
        val rawVersion = flutter.versionName ?: "1.0"
        val parts = rawVersion.split(".")
        val v = if (parts.size >= 2) "${parts[0]}.${parts[1]}" else rawVersion
        val tenFileMoi = "baidoxe_V${v}.apk"

        val buildDir = layout.buildDirectory.asFile.get()
        val thuMucOutputs = listOf(
            File(buildDir, "outputs/apk/release"),
            File(buildDir, "outputs/apk/debug"),
            File(buildDir, "outputs/flutter-apk")
        )

        for (thuMuc in thuMucOutputs) {
            val fileRelease = File(thuMuc, "app-release.apk")
            val fileDebug = File(thuMuc, "app-debug.apk")
            val fileGoc = if (fileRelease.exists()) fileRelease else (if (fileDebug.exists()) fileDebug else null)

            if (fileGoc != null && fileGoc.exists()) {
                val fileDich = File(thuMuc, tenFileMoi)
                fileGoc.copyTo(fileDich, overwrite = true)
                println("==================================================")
                println("[APK XUAT THANH CONG] File APK: ${fileDich.absolutePath}")
                println("==================================================")
            }
        }
    }
}

tasks.matching { it.name.startsWith("assemble") }.configureEach {
    finalizedBy("taoFileApkTheoPhienBan")
}
