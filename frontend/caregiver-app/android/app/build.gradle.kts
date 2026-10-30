import java.util.Base64
import java.util.Properties
import java.net.URI

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val dartDefineValues = (project.findProperty("dart-defines") as? String)
    .orEmpty().split(",").mapNotNull { encoded ->
        runCatching { String(Base64.getDecoder().decode(encoded), Charsets.UTF_8) }
            .getOrNull()
    }.mapNotNull { entry ->
        val separator = entry.indexOf('=')
        if (separator <= 0) null
        else entry.substring(0, separator) to entry.substring(separator + 1)
    }.toMap()

val releaseSigningProperties = Properties()
val releaseSigningPropertiesFile = rootProject.file("key.properties")
if (releaseSigningPropertiesFile.exists()) {
    releaseSigningPropertiesFile.inputStream().use(releaseSigningProperties::load)
}

fun releaseSigningValue(environmentName: String, propertyName: String): String =
    System.getenv(environmentName)?.trim().takeUnless { it.isNullOrEmpty() }
        ?: releaseSigningProperties.getProperty(propertyName)?.trim().orEmpty()

val releaseStoreFile = releaseSigningValue("CARESITTER_UPLOAD_STORE_FILE", "storeFile")
val releaseStorePassword = releaseSigningValue("CARESITTER_UPLOAD_STORE_PASSWORD", "storePassword")
val releaseKeyAlias = releaseSigningValue("CARESITTER_UPLOAD_KEY_ALIAS", "keyAlias")
val releaseKeyPassword = releaseSigningValue("CARESITTER_UPLOAD_KEY_PASSWORD", "keyPassword")
val hasReleaseSigning = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all(String::isNotBlank)

val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
fun isHttpsEndpoint(value: String): Boolean {
    val uri = runCatching { URI(value) }.getOrNull() ?: return false
    return uri.scheme.equals("https", ignoreCase = true) && !uri.host.isNullOrBlank()
}

if (releaseTaskRequested) {
    val appEnvironment = dartDefineValues["APP_ENV"].orEmpty().lowercase()
    val baseUrl = dartDefineValues["BASE_URL"].orEmpty()
    val hubBaseUrl = dartDefineValues["HUB_BASE_URL"].orEmpty()
    val legalBaseUrl = dartDefineValues["LEGAL_BASE_URL"].orEmpty()
    if (appEnvironment !in setOf("production", "prod") ||
        !isHttpsEndpoint(baseUrl) || !isHttpsEndpoint(hubBaseUrl) ||
        !isHttpsEndpoint(legalBaseUrl)
    ) {
        throw GradleException(
            "Release builds require APP_ENV=production plus HTTPS BASE_URL, HUB_BASE_URL " +
                "and LEGAL_BASE_URL. " +
                "Use a debug APK for the temporary Oracle HTTP demo.",
        )
    }
}
if (releaseTaskRequested && !hasReleaseSigning) {
    throw GradleException(
        "Release signing is not configured. Copy android/key.properties.example " +
            "to android/key.properties or set the CARESITTER_UPLOAD_* environment variables.",
    )
}

if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "vn.caresitter.caregiver"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "vn.caresitter.caregiver"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFile)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
