import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// La configuration release reste optionnelle pour les tâches debug et l'analyse,
// mais toute tâche release exige une vraie clé d'upload valide.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val requiredReleaseSigningProperties =
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
var releaseSigningError: String? = null

if (!keystorePropertiesFile.isFile) {
    releaseSigningError = "android/key.properties est absent."
} else {
    try {
        keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
        val missingProperties = requiredReleaseSigningProperties.filter {
            keystoreProperties.getProperty(it).isNullOrBlank()
        }

        releaseSigningError = when {
            missingProperties.isNotEmpty() ->
                "android/key.properties est incomplet : ${missingProperties.joinToString()}."
            !file(keystoreProperties.getProperty("storeFile")).isFile ->
                "Le keystore déclaré par storeFile est introuvable."
            else -> null
        }
    } catch (error: Exception) {
        releaseSigningError =
            "android/key.properties est illisible : ${error.message ?: error.javaClass.simpleName}."
    }
}
val hasValidReleaseSigning = releaseSigningError == null

gradle.taskGraph.whenReady {
    val hasReleaseTask = allTasks.any { task ->
        task.path.contains("Release", ignoreCase = true)
    }
    val signingError = releaseSigningError
    if (hasReleaseTask && signingError != null) {
        throw GradleException(
            "Signature Android release non configurée. $signingError " +
                "Copiez android/key.properties.example vers android/key.properties " +
                "et renseignez un keystore d'upload valide."
        )
    }
}

android {
    namespace = "com.juzreviz.juzreviz"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Requis par flutter_local_notifications (zonedSchedule sur anciens API).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.juzreviz.juzreviz"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasValidReleaseSigning) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasValidReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
