buildscript {
  repositories {
    google()
    mavenCentral()
  }
  dependencies {
    // Android Gradle plugin (match your AGP version)
    classpath("com.android.tools.build:gradle:8.1.1")
    // ← add the Google-Services plugin here
    classpath("com.google.gms:google-services:4.4.0")  // Also update this version
  }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
