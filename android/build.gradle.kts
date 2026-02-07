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

subprojects {
    plugins.withId("com.android.library") {
        val androidExt = extensions.findByName("android") ?: return@withId
        val getNamespace = androidExt.javaClass.methods.firstOrNull { it.name == "getNamespace" }
        val setNamespace = androidExt.javaClass.methods.firstOrNull { it.name == "setNamespace" }
        if (getNamespace != null && setNamespace != null) {
            val current = getNamespace.invoke(androidExt) as? String
            if (current.isNullOrBlank()) {
                val safeName = project.name.replace("-", "_")
                setNamespace.invoke(androidExt, "com.meditative_clarity_hub.$safeName")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
