plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.example.tatehama_trainradio"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.tatehama_trainradio"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
        manifestPlaceholders["appAuthRedirectScheme"] = "tatehama"
    }

    buildFeatures {
        buildConfig = true
    }

    // Add this if it's not already present
    flavorDimensions += "default"

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    sourceSets["main"].manifest.srcFile("app/src/main/AndroidManifest.xml")
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
}
