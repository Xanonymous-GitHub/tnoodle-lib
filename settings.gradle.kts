pluginManagement {
    plugins {
        kotlin("jvm") version "2.3.0"
    }
}
plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "0.8.0"
}
rootProject.name = "tnoodle-lib"

include("min2phase")
include("scrambles")
include("scrambleanalysis")
include("sq12phase")
include("svglite")
include("threephase")
