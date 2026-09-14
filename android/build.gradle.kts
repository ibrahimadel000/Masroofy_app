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
    if (name == "telephony") {
        try {
            if (project.buildFile.exists()) {
                var txt = project.buildFile.readText()
                var modified = false
                val regex = Regex("""compileSdk(?:Version)?[\s(=]+(\d+)""")
                val match = regex.find(txt)
                if (match != null) {
                    val version = match.groupValues[1].toIntOrNull()
                    if (version != null && version < 34) {
                        txt = txt.replace(regex, "compileSdkVersion 34")
                        modified = true
                    }
                }
                if (!txt.contains("namespace")) {
                    txt = txt.replace("android {", "android {\n    namespace 'com.shounakmulay.telephony'")
                    modified = true
                }
                if (txt.contains("kotlinOptions")) {
                    txt = txt.replace(Regex("""kotlinOptions\s*\{[\s\S]*?\}"""), "// kotlinOptions removed")
                    modified = true
                }
                if (txt.contains("compileKotlin")) {
                    txt = txt.replace(Regex("""compileKotlin\s*\{[\s\S]*?\}\s*\}"""), "// compileKotlin removed")
                    modified = true
                }
                if (txt.contains("compileTestKotlin")) {
                    txt = txt.replace(Regex("""compileTestKotlin\s*\{[\s\S]*?\}\s*\}"""), "// compileTestKotlin removed")
                    modified = true
                }
                if (modified) {
                    project.buildFile.setWritable(true)
                    project.buildFile.writeText(txt)
                    println("==> Patched telephony build.gradle (compileSdk 34 + removed legacy compileKotlin)")
                }
            }
        } catch (e: Exception) {
        }
    }

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
        val configureTelephonyKotlin = {
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

        if (state.executed) {
            configureTelephonyKotlin()
        } else {
            afterEvaluate {
                configureTelephonyKotlin()
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
