import java.io.FileInputStream
import java.util.Properties

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
  load(FileInputStream(keystorePropertiesFile))
}

plugins {
  id("com.android.application")
  id("kotlin-android")
  id("dev.flutter.flutter-gradle-plugin")
  id("com.google.gms.google-services")
}

android {
  namespace = "com.risney.games.atoll"
  compileSdk = flutter.compileSdkVersion
  ndkVersion = "27.0.12077973"

  // ——————————————————————————————
  //   SIGNING CONFIGURATION START
  // ——————————————————————————————
  signingConfigs {
    create("release") {
      keyAlias = keystoreProperties["keyAlias"] as String
      keyPassword = keystoreProperties["keyPassword"] as String
      storeFile = file(keystoreProperties["storeFile"] as String)
      storePassword = keystoreProperties["storePassword"] as String
    }
  }

  defaultConfig {
    applicationId = "com.risney.games.atoll"
    minSdk = 23
    targetSdk = flutter.targetSdkVersion
    versionCode = flutter.versionCode
    versionName = flutter.versionName
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }
  kotlinOptions {
    jvmTarget = JavaVersion.VERSION_17.toString()
  }

  buildTypes {
    getByName("release") {
      signingConfig = signingConfigs.getByName("release")
      isMinifyEnabled = true
      proguardFiles(
        getDefaultProguardFile("proguard-android.txt"),
        "proguard-rules.pro"
      )
    }
  }
  // ——————————————————————————————
  //   SIGNING CONFIGURATION END
  // ——————————————————————————————
}

dependencies {
    implementation("com.google.android.gms:play-services-base:18.2.0")
    // If you're using Firebase, these are commonly needed:
    implementation("com.google.firebase:firebase-common:21.0.0")
    
}

flutter {
  source = "../.."
}
