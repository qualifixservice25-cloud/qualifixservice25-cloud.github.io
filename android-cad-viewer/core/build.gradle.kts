plugins {
    alias(libs.plugins.kotlin.jvm)
}

// Nessun toolchain esplicito: il core si compila con la JDK gia' presente (>= 17), cosi'
// il modulo resta testabile anche in ambienti CI minimali senza download di altre JDK.
kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

dependencies {
    testImplementation(kotlin("test"))
}

tasks.test {
    useJUnitPlatform()
    testLogging {
        events("passed", "failed", "skipped")
    }
}
