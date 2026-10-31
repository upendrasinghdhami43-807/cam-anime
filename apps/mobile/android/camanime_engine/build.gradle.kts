import java.util.Properties

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

val flutterSdk: String = Properties().let { props ->
    rootProject.file("local.properties").inputStream().use { props.load(it) }
    requireNotNull(props.getProperty("flutter.sdk")) { "flutter.sdk not set in local.properties" }
}
val flutterEngineHash: String = file("$flutterSdk/bin/internal/engine.version").readText().trim()
val cameraxVersion = "1.6.2"

repositories {
    google()
    mavenCentral()
    maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
}

android {
    namespace = "com.camanime.engine"
    compileSdk = 36

    defaultConfig {
        minSdk = 29
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Flutter embedding is provided by the host app at runtime.
    compileOnly("io.flutter:flutter_embedding_debug:1.0.0-$flutterEngineHash")

    implementation("androidx.camera:camera-core:$cameraxVersion")
    implementation("androidx.camera:camera-camera2:$cameraxVersion")
    implementation("androidx.camera:camera-lifecycle:$cameraxVersion")
    implementation("androidx.core:core-ktx:1.18.0")
    implementation("androidx.lifecycle:lifecycle-common:2.10.0")

    testImplementation("junit:junit:4.13.2")
}
