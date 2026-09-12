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
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val currentNamespace = getNamespace.invoke(android)
                if (currentNamespace == null) {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    val ns = if (name == "telephony") {
                        "com.shounakmulay.telephony"
                    } else {
                        "com.example.${name.replace("-", "_")}"
                    }
                    setNamespace.invoke(android, ns)
                }
            } catch (e: Exception) {
            }
        }
    }

    if (name == "telephony") {
        afterEvaluate {
            tasks.matching { it.name.contains("Kotlin") }.configureEach {
                var setDone = false
                try {
                    val compilerOptions = javaClass.getMethod("getCompilerOptions").invoke(this)
                    val jvmTargetProp = compilerOptions.javaClass.getMethod("getJvmTarget").invoke(compilerOptions)
                    val jvmTargetEnum = Class.forName("org.jetbrains.kotlin.gradle.dsl.JvmTarget").getField("JVM_11").get(null)
                    jvmTargetProp.javaClass.getMethod("set", Any::class.java).invoke(jvmTargetProp, jvmTargetEnum)
                    setDone = true
                } catch (e: Exception) {
                }
                if (!setDone) {
                    try {
                        val kotlinOptions = javaClass.getMethod("getKotlinOptions").invoke(this)
                        kotlinOptions.javaClass.getMethod("setJvmTarget", String::class.java).invoke(kotlinOptions, "11")
                    } catch (e2: Exception) {
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
