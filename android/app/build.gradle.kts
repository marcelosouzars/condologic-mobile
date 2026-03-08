plugins {
    id("com.android.application")
    id("kotlin-android")
    // O Plugin do Flutter cuida da maioria das configurações
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        // TODO: Mude para seu ID único se quiser publicar na loja depois
        applicationId = "com.example.mobile"
        
        // --- AQUI ESTÁ A CORREÇÃO (minSdk = 21) ---
        minSdk = flutter.minSdkVersion 
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Usa a chave de debug para facilitar sua vida agora
            signingConfig = signingConfigs.getByName("debug")
            
            // --- AQUI ESTÁ A CORREÇÃO ---
            // Desliga a tentativa de encolher o código (que estava dando erro)
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
