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

// vosk_flutter_fixed hardcodes compileSdk 33 in its own android/build.gradle,
// which no longer satisfies a transitively-pulled androidx.core version that
// requires compileSdk >= 34 (Gradle's checkReleaseAarMetadata fails
// otherwise) — patched here since we can't edit the published package's
// source directly.
//
// This needs to run AFTER vosk_flutter_fixed's own build.gradle has set
// compileSdk = 33, otherwise that statement runs later in the same script
// and silently overwrites our override back to 33 again (this is exactly
// what happened with a plain plugins.withId hook, which fires as soon as
// the android plugin is applied — i.e. before the subproject's own
// "android { compileSdk 33 }" block further down its script has run).
// But afterEvaluate alone can also fail: Flutter's plugin loader adds
// plugin subprojects dynamically while :app itself is being evaluated, and
// depending on timing a subproject can already be fully evaluated by the
// time this block gets to register the hook for it ("Cannot run
// Project.afterEvaluate(Action) when the project is already evaluated").
// Checking state.executed picks the right one of the two for whichever
// order Gradle happens to process this in.
// withGroovyBuilder avoids needing the AGP classes on this root script's
// own classpath.
subprojects {
    if (project.name == "vosk_flutter_fixed") {
        val patchCompileSdk = {
            project.extensions.findByName("android")?.withGroovyBuilder {
                setProperty("compileSdk", 34)
            }
        }
        if (project.state.executed) {
            patchCompileSdk()
        } else {
            afterEvaluate { patchCompileSdk() }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
