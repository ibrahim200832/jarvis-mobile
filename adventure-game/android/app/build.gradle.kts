plugins {
    id("com.android.application")
}

android {
    namespace = "com.jarvismobile.adventuregame"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.jarvismobile.adventuregame"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
}
