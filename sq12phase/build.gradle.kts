import configurations.Languages.attachRemoteRepositories
import configurations.Languages.configureJava
import configurations.Publications.configureMavenPublication
import configurations.Publications.configureSignatures

description = "A copy of Chen Shuang's square 1 two phase solver."

plugins {
    `java-library`
    `maven-publish`
    signing
}

configureJava()
configureMavenPublication("scrambler-sq12phase")
configureSignatures(publishing)

attachRemoteRepositories()

dependencies {
    implementation(libs.slf4j.api)

    testImplementation(libs.junit.jupiter.api)
    testImplementation(libs.junit.jupiter.engine)

    testRuntimeOnly(libs.junit.platform.launcher)
}
