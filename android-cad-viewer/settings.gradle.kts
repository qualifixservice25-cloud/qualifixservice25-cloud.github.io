import java.io.File

pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "cad-viewer"

// Il modulo :core e' Kotlin puro (parsing DXF, geometria, motore di quotatura) e
// si compila e testa su qualsiasi JVM, anche senza SDK Android: e' quello che gira in CI.
include(":core")

// Il modulo :app richiede l'SDK Android. Android Studio lo trova sempre (ANDROID_HOME o
// local.properties); su una macchina senza SDK lo escludiamo, cosi' `gradle test` sul core
// resta eseguibile invece di fallire in configurazione con "SDK location not found".
val androidSdkAvailable: Boolean =
    sequenceOf(System.getenv("ANDROID_HOME"), System.getenv("ANDROID_SDK_ROOT"))
        .any { !it.isNullOrBlank() && File(it, "platforms").isDirectory } ||
        File(rootDir, "local.properties").exists()

if (androidSdkAvailable) {
    include(":app")
} else {
    println("[cad-viewer] SDK Android non trovato: build limitata al modulo :core.")
}
