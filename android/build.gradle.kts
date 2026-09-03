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

// gradle.afterProject fires for every project AFTER its build script AND all
// afterEvaluate{} hooks have run. This is the correct place to override
// compileSdk for Flutter plugin subprojects whose compileSdkVersion is set
// by the Flutter Gradle plugin in an afterEvaluate block (e.g. connectivity_plus).
gradle.afterProject {
    val lib = project.extensions.findByType<com.android.build.gradle.LibraryExtension>()
    if (lib != null && (lib.compileSdk ?: 0) < 36) {
        lib.compileSdk = 36
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
