plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val productionKeystorePath = System.getenv("KELASKU_RELEASE_KEYSTORE")?.takeIf { it.isNotBlank() }
val productionKeystorePassword = System.getenv("KELASKU_KEYSTORE_PASSWORD")?.takeIf { it.isNotBlank() }
val releaseRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (releaseRequested && (productionKeystorePath == null || productionKeystorePassword == null)) {
    throw GradleException(
        "Release signing requires KELASKU_RELEASE_KEYSTORE and KELASKU_KEYSTORE_PASSWORD."
    )
}
if (releaseRequested && !file(productionKeystorePath!!).isFile) {
    throw GradleException("The production keystore file does not exist.")
}

android {
    namespace = "com.presensiku.presensiku"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.presensiku.presensiku"
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

    signingConfigs {
        create("production") {
            if (productionKeystorePath != null && productionKeystorePassword != null) {
                storeFile = file(productionKeystorePath)
                storePassword = productionKeystorePassword
                keyAlias = "kelasku_release"
                keyPassword = productionKeystorePassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("production")
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
