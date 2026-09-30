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
// source directly. Flutter's plugin loader adds plugin subprojects
// dynamically while :app itself is being evaluated, so an afterEvaluate
// hook here can race with a subproject that's already finished evaluating
// by the time it's registered ("Cannot run Project.afterEvaluate(Action)
// when the project is already evaluated"); plugins.withId fires immediately
// if the plugin is already applied, so it isn't subject to that race.
// withGroovyBuilder avoids needing the AGP classes on this root script's
// own classpath.
subprojects {
    plugins.withId("com.android.library") {
        if (project.name == "vosk_flutter_fixed") {
            project.extensions.findByName("android")?.withGroovyBuilder {
                setProperty("compileSdk", 34)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
