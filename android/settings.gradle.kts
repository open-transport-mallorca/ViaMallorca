pluginManagement {
    val flutterSdkPath: String = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        checkNotNull(flutterSdkPath) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild(file("$flutterSdkPath/packages/flutter_tools/gradle").toPath().toRealPath().toAbsolutePath().toString())

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.0" apply false
}

include(":app")
