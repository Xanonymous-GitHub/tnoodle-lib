import configurations.Languages.attachRemoteRepositories
import configurations.Languages.configureJava
import configurations.Frameworks.configureCheckstyle
import configurations.Frameworks.configureJUnit5
import configurations.Publications.configureMavenPublication
import configurations.Publications.configureSignatures

description = "A Java scrambling suite. Java applications can use this project as a library. A perfect example of this is the webscrambles package."

plugins {
    `java-library`
    checkstyle
    `maven-publish`
    signing
    alias(libs.plugins.shadow)
    kotlin("jvm")
}

attachRemoteRepositories()

configureJava()
configureCheckstyle()
configureMavenPublication("lib-scrambles")
configureSignatures(publishing)

dependencies {
    api(project(":svglite"))

    implementation(project(":min2phase"))
    implementation(project(":threephase"))
    implementation(project(":sq12phase"))

    api(libs.gwt.exporter)

    testImplementation(libs.junit.jupiter.api)
    testImplementation(libs.junit.jupiter.engine)

    testRuntimeOnly(libs.junit.platform.launcher)
    implementation(kotlin("stdlib-jdk8"))
}

configureJUnit5()

tasks.shadowJar {
    mergeServiceFiles()

    // Handle duplicate META-INF files (signature files can cause conflicts)
    exclude("META-INF/*.SF", "META-INF/*.DSA", "META-INF/*.RSA")

    // Workaround for Shadow plugin bug with empty META-INF directories
    // https://github.com/GradleUp/shadow/issues/111
    isPreserveFileTimestamps = false
    isReproducibleFileOrder = true
}
repositories {
    mavenCentral()
}
kotlin {
    jvmToolchain(25)
}
