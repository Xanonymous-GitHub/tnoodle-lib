allprojects {
    group = "org.worldcubeassociation.tnoodle"
    version = "0.20.0"
}

plugins {
    alias(libs.plugins.dependency.versions)
    alias(libs.plugins.nexus.publish)
}

nexusPublishing {
    repositories {
        sonatype {
            nexusUrl.set(uri("https://s01.oss.sonatype.org/service/local/"))
            snapshotRepositoryUrl.set(uri("https://s01.oss.sonatype.org/content/repositories/snapshots/"))
        }
    }
}

tasks.register("generateDebugRelease") {
    dependsOn(":scrambles:shadowJar")
}

tasks.register("showClassPath") {
    dependsOn(":scrambles:assemble")

    val pj = rootProject.subprojects.first { it.path == ":scrambles" }
    val cp = pj.configurations
        .getByName("runtimeClasspath").files
        .joinToString("\n") { it.absolutePath }

    println(cp)
}

tasks.register("showJ2objcDepSources") {
    // Resolve sources for the same classpath you will translate: :scrambles runtimeClasspath
    dependsOn(":scrambles:assemble")

    val scrambles = rootProject.subprojects.first { it.path == ":scrambles" }
    val cp = scrambles.configurations.getByName("runtimeClasspath")

    val sourcesView = cp.incoming.artifactView {
        withVariantReselection()
        attributes {
            attribute(Category.CATEGORY_ATTRIBUTE, scrambles.objects.named(Category.DOCUMENTATION))
            attribute(DocsType.DOCS_TYPE_ATTRIBUTE, scrambles.objects.named(DocsType.SOURCES))
            attribute(Bundling.BUNDLING_ATTRIBUTE, scrambles.objects.named(Bundling.EXTERNAL))
        }
    }

    // Print resolved sources jars (one per line)
    doLast {
        val sourcesFiles = sourcesView.files.files.sortedBy { it.absolutePath }
        sourcesFiles.forEach { println(it.absolutePath) }

        // Extra: report external deps that did NOT publish sources.
        val runtimeModules: Set<ModuleComponentIdentifier> = cp.incoming.resolutionResult.allComponents
            .mapNotNull { it.id as? ModuleComponentIdentifier }
            .toSet()

        val sourcesModules: Set<ModuleComponentIdentifier> = sourcesView.artifacts.artifacts
            .mapNotNull { it.id.componentIdentifier as? ModuleComponentIdentifier }
            .toSet()

        val missingSources = (runtimeModules - sourcesModules)
            .sortedBy { "${it.group}:${it.module}:${it.version}" }

        if (missingSources.isNotEmpty()) {
            logger.warn("\n[showJ2objcDepSources] The following external runtime dependencies did not resolve a sources variant (may not publish sources):")
            missingSources.forEach { logger.warn("  - ${it.group}:${it.module}:${it.version}") }
        }
    }
}
