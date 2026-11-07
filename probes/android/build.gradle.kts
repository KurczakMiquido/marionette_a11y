plugins {
    id("com.android.application") version "9.0.1"
    // Pins the Kotlin version AGP's built-in Kotlin support compiles with.
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

android {
    namespace = "dev.a11y.probe"
    compileSdk = 36

    defaultConfig {
        applicationId = "dev.a11y.probe"
        minSdk = 30
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("com.google.android.apps.common.testing.accessibility.framework:accessibility-test-framework:4.1.1")
    // ATF's API returns Guava types but its POM scopes Guava as runtime-only; same version ATF pulls in.
    androidTestCompileOnly("com.google.guava:guava:31.0.1-android")
}
