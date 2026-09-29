allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Some plugins (e.g. porcupine_flutter, used for the "Jarvis" wake word)
// hardcode an old compileSdkVersion in their own Android build.gradle,
// independent of this app's `flutter.compileSdkVersion` setting in
// app/build.gradle.kts. Newer androidx libraries pulled in by other
// plugins require a higher compileSdk, so AGP's AAR metadata check fails
// the release build with "X requires ... compileSdk of at least 34/36,
// but :porcupine_flutter is currently compiled against android-31."
// Forcing every library subproject to the same, sufficiently new
// compileSdk sidesteps that mismatch without needing to patch or fork
// the plugin itself.
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)?.let { library ->
            if ((library.compileSdk ?: 0) < 36) {
                library.compileSdk = 36
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
