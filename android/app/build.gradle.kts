import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

android {
    namespace = "es.opentransportmallorca.via"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    kotlin {
        jvmToolchain(17)
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "es.opentransportmallorca.via"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    signingConfigs {
        create("release") {
            if (System.getenv("CI") != null) {
                storeFile = file(System.getenv("CM_KEYSTORE_PATH")!!)
                storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("CM_KEY_ALIAS")
                keyPassword = System.getenv("CM_KEY_PASSWORD")
            } else {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
        }

        getByName("profile") {
            isMinifyEnabled = true
            signingConfig = signingConfigs.getByName("debug")
        }

        getByName("debug") {
            isMinifyEnabled = true
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
