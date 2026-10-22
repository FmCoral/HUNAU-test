plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "mou.mou.mou"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    defaultConfig {
        applicationId = "mou.mou.mou"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        getByName("debug") {
            applicationIdSuffix = ".debug"
        }
        release {
            // 使用上面定义的 release 签名配置
            signingConfig = signingConfigs.getByName("release")
            
            // 启用代码压缩与资源缩减
            isMinifyEnabled = true
            isShrinkResources = true

            // 启用自定义混淆规则
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    // Live Updates 需要 NotificationCompat.ProgressStyle / setRequestPromotedOngoing (core 1.17+)
    implementation("androidx.core:core:1.17.0")
    // 16 KB 页对齐：CameraX 1.3.x 的 libimage_processing_util_jni.so 仅 4 KB 对齐，
    // 1.4.2 起全部 ABI 均为 16 KB 对齐（mobile_scanner 传递依赖）
    implementation("androidx.camera:camera-core:1.4.2")
    implementation("androidx.camera:camera-camera2:1.4.2")
    implementation("androidx.camera:camera-lifecycle:1.4.2")
    // 16 KB 页对齐：barcode-scanning 17.3.0 的 libbarhopper_v3.so 在 64 位 ABI 上已 16 KB 对齐
    implementation("com.google.mlkit:barcode-scanning:17.3.0")
}

flutter {
    source = "../.."
}
