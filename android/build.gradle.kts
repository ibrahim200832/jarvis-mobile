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
//
// Timing here is delicate: a plain `subprojects { afterEvaluate { ... } }`
// fails with "Cannot run Project.afterEvaluate(Action) when the project
// is already evaluated", because `evaluationDependsOn(":app")` above
// forces some subprojects to finish evaluating before that block even
// runs. A `plugins.withId("com.android.library") { ... }` override fires
// too *early* instead — right when `apply plugin: 'com.android.library'`
// runs in porcupine_flutter's own build.gradle, which is the first line
// of that script; the `compileSdkVersion 31` statement further down in
// that same script then runs afterwards and clobbers our override back
// down to 31. `gradle.projectsEvaluated` sidesteps both problems: it's a
// Gradle-wide (not per-project) callback that only fires once every
// project's build script — :app, :porcupine_flutter, all of them — has
// fully finished evaluating, so there's nothing left to overwrite our
// value afterwards, and no per-project afterEvaluate registration to
// reject as "already evaluated".
gradle.projectsEvaluated {
    subprojects {
        extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)?.let { library ->
            if ((library.compileSdk ?: 0) < 36) {
                library.compileSdk = 36
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
