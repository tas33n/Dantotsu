#!/usr/bin/env bash
# =============================================================================
#  NotificationVault — Android Dev Environment Setup for GitHub Codespaces
#  Run: bash setup-android-codespace.sh
#  Tested on: Ubuntu 22.04 (default Codespaces base image)
# =============================================================================

set -euo pipefail

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()    { echo -e "${CYAN}${BOLD}[SETUP]${NC} $1"; }
ok()     { echo -e "${GREEN}${BOLD}[  OK  ]${NC} $1"; }
warn()   { echo -e "${YELLOW}${BOLD}[ WARN ]${NC} $1"; }
fail()   { echo -e "${RED}${BOLD}[FAIL  ]${NC} $1"; exit 1; }
section(){ echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════${NC}"; \
           echo -e "${BOLD}${CYAN}  $1${NC}"; \
           echo -e "${BOLD}${CYAN}══════════════════════════════════════════${NC}\n"; }

# ─── Versions (pin for reproducibility) ──────────────────────────────────────
JAVA_VERSION="17"
ANDROID_CMDTOOLS_VERSION="11076708"          # commandlinetools-linux rev
ANDROID_CMDTOOLS_SHA256="2d2d50857e4eb553af5a6dc3ad507a17adf43d115264b1afc116f95c92e5e258"
ANDROID_BUILD_TOOLS_VERSION="35.0.0"
ANDROID_PLATFORM_VERSION="36"               # Android 16 (API 36)
ANDROID_PLATFORM_MIN="31"                   # Android 12 (API 31) — also install
GRADLE_VERSION="8.8"
KOTLIN_VERSION="2.0.0"
AGP_VERSION="8.5.0"                         # Android Gradle Plugin

ANDROID_HOME="${HOME}/android-sdk"
CMDTOOLS_DIR="${ANDROID_HOME}/cmdline-tools/latest"

section "1 / 9 — System packages"

log "Updating apt..."
sudo apt-get update -qq

log "Installing core dependencies..."
sudo apt-get install -y -qq \
    curl wget unzip zip git \
    openjdk-${JAVA_VERSION}-jdk \
    build-essential \
    lib32stdc++6 lib32z1 \
    libpulse0 \
    xdg-utils \
    ca-certificates \
    gnupg \
    lsb-release \
    jq \
    tree \
    htop

ok "System packages installed"

# ─── Java ─────────────────────────────────────────────────────────────────────
section "2 / 9 — Java ${JAVA_VERSION}"

JAVA_HOME_PATH=$(dirname $(dirname $(readlink -f $(which java))))
export JAVA_HOME="${JAVA_HOME_PATH}"

java -version 2>&1 | head -1
ok "Java ${JAVA_VERSION} ready — JAVA_HOME=${JAVA_HOME}"

# ─── Android SDK Command Line Tools ──────────────────────────────────────────
section "3 / 9 — Android SDK"

log "Creating SDK directory at ${ANDROID_HOME}..."
mkdir -p "${CMDTOOLS_DIR}"

CMDTOOLS_ZIP="/tmp/android-cmdtools.zip"

log "Downloading Android command line tools (rev ${ANDROID_CMDTOOLS_VERSION})..."
wget -q --show-progress \
    "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDTOOLS_VERSION}_latest.zip" \
    -O "${CMDTOOLS_ZIP}"

log "Verifying download checksum..."
echo "${ANDROID_CMDTOOLS_SHA256}  ${CMDTOOLS_ZIP}" | sha256sum --check --quiet \
    || warn "Checksum mismatch — continuing anyway (version may have updated)"

log "Extracting command line tools..."
TMPDIR_TOOLS=$(mktemp -d)
unzip -q "${CMDTOOLS_ZIP}" -d "${TMPDIR_TOOLS}"
# Google zips as cmdline-tools/ — move contents to our latest/ dir
cp -r "${TMPDIR_TOOLS}/cmdline-tools/." "${CMDTOOLS_DIR}/"
rm -rf "${TMPDIR_TOOLS}" "${CMDTOOLS_ZIP}"

ok "Command line tools extracted"

# ─── Environment variables ────────────────────────────────────────────────────
section "4 / 9 — Environment variables"

export ANDROID_HOME="${ANDROID_HOME}"
export ANDROID_SDK_ROOT="${ANDROID_HOME}"
export PATH="${PATH}:${CMDTOOLS_DIR}/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator"

log "Writing env vars to ~/.bashrc, ~/.zshrc, ~/.profile..."

ENV_BLOCK=$(cat <<'ENVEOF'

# ── Android SDK ────────────────────────────────────────────────────────
export JAVA_HOME="$(dirname $(dirname $(readlink -f $(which java))))"
export ANDROID_HOME="${HOME}/android-sdk"
export ANDROID_SDK_ROOT="${ANDROID_HOME}"
export PATH="${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin"
export PATH="${PATH}:${ANDROID_HOME}/platform-tools"
export PATH="${PATH}:${ANDROID_HOME}/emulator"
export PATH="${PATH}:${ANDROID_HOME}/build-tools/35.0.0"
# ──────────────────────────────────────────────────────────────────────
ENVEOF
)

for rc_file in "${HOME}/.bashrc" "${HOME}/.zshrc" "${HOME}/.profile"; do
    if [ -f "${rc_file}" ]; then
        # Remove previous block if it exists
        if grep -q "Android SDK" "${rc_file}" 2>/dev/null; then
            warn "Existing Android SDK env found in ${rc_file}, skipping..."
        else
            echo "${ENV_BLOCK}" >> "${rc_file}"
            ok "Updated ${rc_file}"
        fi
    fi
done

ok "Environment variables configured"

# ─── SDK packages via sdkmanager ──────────────────────────────────────────────
section "5 / 9 — Android SDK packages"

log "Accepting all SDK licenses..."
yes | "${CMDTOOLS_DIR}/bin/sdkmanager" --licenses > /dev/null 2>&1 || true

log "Installing Android platform API ${ANDROID_PLATFORM_VERSION} (Android 16)..."
"${CMDTOOLS_DIR}/bin/sdkmanager" "platforms;android-${ANDROID_PLATFORM_VERSION}"

log "Installing Android platform API ${ANDROID_PLATFORM_MIN} (Android 12 — minSdk)..."
"${CMDTOOLS_DIR}/bin/sdkmanager" "platforms;android-${ANDROID_PLATFORM_MIN}"

log "Installing Android platform API 33 (Android 13)..."
"${CMDTOOLS_DIR}/bin/sdkmanager" "platforms;android-33"

log "Installing Build Tools ${ANDROID_BUILD_TOOLS_VERSION}..."
"${CMDTOOLS_DIR}/bin/sdkmanager" "build-tools;${ANDROID_BUILD_TOOLS_VERSION}"

log "Installing Build Tools 34.0.0 (for compatibility)..."
"${CMDTOOLS_DIR}/bin/sdkmanager" "build-tools;34.0.0"

log "Installing Platform Tools (adb, fastboot)..."
"${CMDTOOLS_DIR}/bin/sdkmanager" "platform-tools"

log "Installing extras..."
"${CMDTOOLS_DIR}/bin/sdkmanager" \
    "extras;android;m2repository" \
    "extras;google;m2repository" \
    "extras;google;google_play_services"

log "Installed SDK packages:"
"${CMDTOOLS_DIR}/bin/sdkmanager" --list_installed 2>/dev/null | grep -v "^$" || true

ok "Android SDK packages installed"

# ─── Gradle ──────────────────────────────────────────────────────────────────
section "6 / 9 — Gradle ${GRADLE_VERSION}"

GRADLE_ZIP="/tmp/gradle-${GRADLE_VERSION}-bin.zip"
GRADLE_DIR="${HOME}/.gradle/wrapper/dists/gradle-${GRADLE_VERSION}-bin"

log "Downloading Gradle ${GRADLE_VERSION}..."
wget -q --show-progress \
    "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" \
    -O "${GRADLE_ZIP}"

log "Installing Gradle to /opt/gradle..."
sudo mkdir -p /opt/gradle
sudo unzip -q "${GRADLE_ZIP}" -d /opt/gradle
rm "${GRADLE_ZIP}"

GRADLE_BIN="/opt/gradle/gradle-${GRADLE_VERSION}/bin"
sudo ln -sf "${GRADLE_BIN}/gradle" /usr/local/bin/gradle

log "Gradle version: $(gradle --version | grep Gradle)"

# Pre-populate Gradle wrapper cache so first build is faster
mkdir -p "${HOME}/.gradle/wrapper/dists"

ok "Gradle ${GRADLE_VERSION} installed"

# ─── Gradle global config ─────────────────────────────────────────────────────
section "7 / 9 — Gradle & build configuration"

mkdir -p "${HOME}/.gradle"

cat > "${HOME}/.gradle/gradle.properties" <<GRADLEEOF
# ── NotificationVault global Gradle properties ────────────────────────
# Performance
org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=512m -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8
org.gradle.parallel=true
org.gradle.caching=true
org.gradle.configureondemand=true
org.gradle.daemon=true

# Android
android.useAndroidX=true
android.enableJetifier=false
android.nonTransitiveRClass=true
android.nonFinalResIds=false

# Kotlin
kotlin.incremental=true
kotlin.incremental.java=true
kotlin.daemon.jvm.options=-Xmx2g

# Compose
android.defaults.buildfeatures.compose=true

# Suppress warnings
android.suppressUnsupportedCompileSdkWarnings=true
GRADLEEOF

ok "Gradle global properties configured (~/.gradle/gradle.properties)"

# ─── Project scaffold ─────────────────────────────────────────────────────────
section "8 / 9 — Project scaffold"

PROJECT_DIR="${HOME}/NotificationVault"

if [ -d "${PROJECT_DIR}" ]; then
    warn "Project directory already exists at ${PROJECT_DIR} — skipping scaffold"
else
    log "Creating project at ${PROJECT_DIR}..."
    mkdir -p "${PROJECT_DIR}"
    cd "${PROJECT_DIR}"

    # ── Root build.gradle.kts ──────────────────────────────────────────
    cat > "build.gradle.kts" <<'EOF'
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.hilt) apply false
    alias(libs.plugins.ksp) apply false
}
EOF

    # ── settings.gradle.kts ───────────────────────────────────────────
    cat > "settings.gradle.kts" <<'EOF'
pluginManagement {
    repositories {
        google { content { includeGroupByRegex("com\\.android.*"); includeGroupByRegex("com\\.google.*"); includeGroupByRegex("androidx.*") } }
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "NotificationVault"
include(":app")
EOF

    # ── libs.versions.toml ────────────────────────────────────────────
    mkdir -p "gradle"
    cat > "gradle/libs.versions.toml" <<'EOF'
[versions]
agp                     = "8.5.0"
kotlin                  = "2.0.0"
ksp                     = "2.0.0-1.0.21"
composeBom              = "2024.06.00"
hilt                    = "2.51.1"
hiltNavigationCompose   = "1.2.0"
room                    = "2.6.1"
datastore               = "1.1.1"
coil                    = "2.6.0"
coroutines              = "1.8.1"
lifecycle               = "2.8.2"
navigationCompose       = "2.7.7"
activityCompose         = "1.9.0"
biometric               = "1.2.0-alpha05"
workRuntime             = "2.9.0"
timber                  = "5.0.1"
coreKtx                 = "1.13.1"
splashscreen            = "1.0.1"
junitVersion            = "4.13.2"
androidxTestExt         = "1.2.1"
espresso                = "3.6.1"

[libraries]
# AndroidX Core
androidx-core-ktx              = { group = "androidx.core",           name = "core-ktx",                  version.ref = "coreKtx" }
androidx-splashscreen          = { group = "androidx.core",           name = "core-splashscreen",          version.ref = "splashscreen" }

# Compose
compose-bom                    = { group = "androidx.compose",        name = "compose-bom",                version.ref = "composeBom" }
compose-ui                     = { group = "androidx.compose.ui",     name = "ui" }
compose-ui-graphics            = { group = "androidx.compose.ui",     name = "ui-graphics" }
compose-ui-tooling-preview     = { group = "androidx.compose.ui",     name = "ui-tooling-preview" }
compose-ui-tooling             = { group = "androidx.compose.ui",     name = "ui-tooling" }
compose-ui-test-manifest       = { group = "androidx.compose.ui",     name = "ui-test-manifest" }
compose-ui-test-junit4         = { group = "androidx.compose.ui",     name = "ui-test-junit4" }
compose-material3              = { group = "androidx.compose.material3", name = "material3" }
compose-material-icons-extended = { group = "androidx.compose.material", name = "material-icons-extended" }
compose-activity               = { group = "androidx.activity",       name = "activity-compose",           version.ref = "activityCompose" }
compose-navigation             = { group = "androidx.navigation",     name = "navigation-compose",         version.ref = "navigationCompose" }

# Lifecycle
lifecycle-viewmodel-compose    = { group = "androidx.lifecycle",      name = "lifecycle-viewmodel-compose", version.ref = "lifecycle" }
lifecycle-runtime-compose      = { group = "androidx.lifecycle",      name = "lifecycle-runtime-compose",  version.ref = "lifecycle" }

# Hilt
hilt-android                   = { group = "com.google.dagger",       name = "hilt-android",               version.ref = "hilt" }
hilt-compiler                  = { group = "com.google.dagger",       name = "hilt-android-compiler",      version.ref = "hilt" }
hilt-navigation-compose        = { group = "androidx.hilt",           name = "hilt-navigation-compose",    version.ref = "hiltNavigationCompose" }

# Room
room-runtime                   = { group = "androidx.room",           name = "room-runtime",               version.ref = "room" }
room-ktx                       = { group = "androidx.room",           name = "room-ktx",                   version.ref = "room" }
room-compiler                  = { group = "androidx.room",           name = "room-compiler",              version.ref = "room" }

# DataStore
datastore-preferences          = { group = "androidx.datastore",      name = "datastore-preferences",      version.ref = "datastore" }

# Coil
coil-compose                   = { group = "io.coil-kt",              name = "coil-compose",               version.ref = "coil" }

# Coroutines
coroutines-android             = { group = "org.jetbrains.kotlinx",   name = "kotlinx-coroutines-android", version.ref = "coroutines" }

# Biometric
biometric                      = { group = "androidx.biometric",      name = "biometric",                  version.ref = "biometric" }

# WorkManager
work-runtime-ktx               = { group = "androidx.work",           name = "work-runtime-ktx",           version.ref = "workRuntime" }

# Logging
timber                         = { group = "com.jakewharton.timber",  name = "timber",                     version.ref = "timber" }

# Testing
junit                          = { group = "junit",                   name = "junit",                      version.ref = "junitVersion" }
androidx-test-ext-junit        = { group = "androidx.test.ext",       name = "junit",                      version.ref = "androidxTestExt" }
espresso-core                  = { group = "androidx.test.espresso",  name = "espresso-core",              version.ref = "espresso" }

[plugins]
android-application  = { id = "com.android.application",             version.ref = "agp" }
kotlin-android       = { id = "org.jetbrains.kotlin.android",        version.ref = "kotlin" }
kotlin-compose       = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
hilt                 = { id = "com.google.dagger.hilt.android",      version.ref = "hilt" }
ksp                  = { id = "com.google.devtools.ksp",             version.ref = "ksp" }
EOF

    # ── gradlew wrapper ───────────────────────────────────────────────
    gradle wrapper --gradle-version="${GRADLE_VERSION}" --distribution-type=bin 2>/dev/null || {
        warn "gradle wrapper cmd failed, creating wrapper manually..."
        mkdir -p "gradle/wrapper"
        cat > "gradle/wrapper/gradle-wrapper.properties" <<WRAPEOF
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip
networkTimeout=10000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
WRAPEOF
    }

    # ── app/ module ───────────────────────────────────────────────────
    mkdir -p "app/src/main/kotlin/com/notificationvault/app"
    mkdir -p "app/src/main/res/values"
    mkdir -p "app/src/main/res/xml"
    mkdir -p "app/src/test/kotlin/com/notificationvault/app"
    mkdir -p "app/src/androidTest/kotlin/com/notificationvault/app"

    cat > "app/build.gradle.kts" <<'EOF'
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.hilt)
    alias(libs.plugins.ksp)
}

android {
    namespace = "com.notificationvault.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.notificationvault.app"
        minSdk = 31
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables { useSupportLibrary = true }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        debug {
            applicationIdSuffix = ".debug"
            isDebuggable = true
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions { jvmTarget = "17" }

    buildFeatures { compose = true }

    packaging {
        resources { excludes += "/META-INF/{AL2.0,LGPL2.1}" }
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.splashscreen)
    // Compose
    val composeBom = platform(libs.compose.bom)
    implementation(composeBom)
    androidTestImplementation(composeBom)
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons.extended)
    implementation(libs.compose.activity)
    implementation(libs.compose.navigation)
    debugImplementation(libs.compose.ui.tooling)
    debugImplementation(libs.compose.ui.test.manifest)
    // Lifecycle
    implementation(libs.lifecycle.viewmodel.compose)
    implementation(libs.lifecycle.runtime.compose)
    // Hilt
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    implementation(libs.hilt.navigation.compose)
    // Room
    implementation(libs.room.runtime)
    implementation(libs.room.ktx)
    ksp(libs.room.compiler)
    // DataStore
    implementation(libs.datastore.preferences)
    // Coil
    implementation(libs.coil.compose)
    // Coroutines
    implementation(libs.coroutines.android)
    // Biometric
    implementation(libs.biometric)
    // WorkManager
    implementation(libs.work.runtime.ktx)
    // Timber
    implementation(libs.timber)
    // Testing
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.espresso.core)
    androidTestImplementation(libs.compose.ui.test.junit4)
}
EOF

    # ── AndroidManifest.xml ───────────────────────────────────────────
    cat > "app/src/main/AndroidManifest.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

    <application
        android:name=".NotificationVaultApp"
        android:allowBackup="false"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:supportsRtl="true"
        android:theme="@style/Theme.NotificationVault">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <service
            android:name=".service.VaultNotificationListenerService"
            android:label="@string/service_label"
            android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE"
            android:exported="true">
            <intent-filter>
                <action android:name="android.service.notification.NotificationListenerService"/>
            </intent-filter>
            <meta-data
                android:name="android.service.notification.default_filter_types"
                android:value="conversations"/>
        </service>

        <receiver
            android:name=".receiver.BootReceiver"
            android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
            </intent-filter>
        </receiver>

    </application>
</manifest>
EOF

    # ── res/values/strings.xml ────────────────────────────────────────
    cat > "app/src/main/res/values/strings.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">NotificationVault</string>
    <string name="service_label">NotificationVault Listener</string>
</resources>
EOF

    # ── res/values/themes.xml ─────────────────────────────────────────
    cat > "app/src/main/res/values/themes.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.NotificationVault" parent="android:Theme.Material.Light.NoActionBar"/>
</resources>
EOF

    # ── Main Application class ────────────────────────────────────────
    cat > "app/src/main/kotlin/com/notificationvault/app/NotificationVaultApp.kt" <<'EOF'
package com.notificationvault.app

import android.app.Application
import dagger.hilt.android.HiltAndroidApp
import timber.log.Timber

@HiltAndroidApp
class NotificationVaultApp : Application() {
    override fun onCreate() {
        super.onCreate()
        if (BuildConfig.DEBUG) {
            Timber.plant(Timber.DebugTree())
        }
    }
}
EOF

    # ── MainActivity stub ─────────────────────────────────────────────
    cat > "app/src/main/kotlin/com/notificationvault/app/MainActivity.kt" <<'EOF'
package com.notificationvault.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            // TODO: NotificationVaultTheme { AppNavHost() }
        }
    }
}
EOF

    # ── Stub service ──────────────────────────────────────────────────
    mkdir -p "app/src/main/kotlin/com/notificationvault/app/service"
    cat > "app/src/main/kotlin/com/notificationvault/app/service/VaultNotificationListenerService.kt" <<'EOF'
package com.notificationvault.app.service

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import timber.log.Timber

class VaultNotificationListenerService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return
        // TODO: filter by package, extract extras, store to Room DB
        Timber.d("Notification posted: pkg=${sbn.packageName}")
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        sbn ?: return
        Timber.d("Notification removed: pkg=${sbn.packageName}")
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Timber.i("NotificationListenerService connected")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Timber.w("NotificationListenerService disconnected")
    }
}
EOF

    # ── Stub BootReceiver ─────────────────────────────────────────────
    mkdir -p "app/src/main/kotlin/com/notificationvault/app/receiver"
    cat > "app/src/main/kotlin/com/notificationvault/app/receiver/BootReceiver.kt" <<'EOF'
package com.notificationvault.app.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import timber.log.Timber

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Timber.i("Boot completed — service will reconnect automatically")
            // NotificationListenerService re-binds automatically after boot
            // No manual restart needed; this receiver is a hook for future work
        }
    }
}
EOF

    # ── proguard-rules.pro ────────────────────────────────────────────
    cat > "app/proguard-rules.pro" <<'EOF'
# Hilt
-keep class dagger.hilt.** { *; }
-keep class javax.inject.** { *; }
# Room
-keep class * extends androidx.room.RoomDatabase
-keep @androidx.room.Entity class *
# Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
# Timber
-dontwarn org.jetbrains.annotations.**
EOF

    # ── .gitignore ────────────────────────────────────────────────────
    cat > ".gitignore" <<'EOF'
*.iml
.gradle/
local.properties
.idea/
.DS_Store
build/
captures/
app/build/
.externalNativeBuild/
.cxx/
*.keystore
!debug.keystore
google-services.json
EOF

    # ── README stub ───────────────────────────────────────────────────
    cat > "README.md" <<'EOF'
# NotificationVault

> Open-source notification history app for Android 12–16.  
> Captures messages before they're unsent. 100% local. No cloud. No ads.

## License
GNU GPL v3.0 — see [LICENSE](LICENSE)

## Building
```bash
./gradlew assembleDebug
```

## Contributing
See [CONTRIBUTING.md](CONTRIBUTING.md)
EOF

    # ── LICENSE (GPL v3 header) ───────────────────────────────────────
    cat > "LICENSE" <<'EOF'
NotificationVault — Notification history manager for Android
Copyright (C) 2024  NotificationVault Contributors

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
EOF

    log "Project scaffolded at ${PROJECT_DIR}"
    ok "Project scaffold created"
fi

# ─── VS Code / Codespaces extensions ──────────────────────────────────────────
section "9 / 9 — VS Code extensions & devcontainer"

# Write .devcontainer config for future re-opens
mkdir -p "${HOME}/NotificationVault/.devcontainer"
cat > "${HOME}/NotificationVault/.devcontainer/devcontainer.json" <<'EOF'
{
  "name": "NotificationVault Android Dev",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu-22.04",
  "postCreateCommand": "bash setup-android-codespace.sh",
  "customizations": {
    "vscode": {
      "extensions": [
        "mathiasfrohlich.Kotlin",
        "fwcd.kotlin",
        "vscjava.vscode-java-pack",
        "esbenp.prettier-vscode",
        "eamodio.gitlens",
        "mhutchie.git-graph",
        "usernamehw.errorlens",
        "streetsidesoftware.code-spell-checker",
        "pkief.material-icon-theme",
        "github.copilot"
      ],
      "settings": {
        "editor.formatOnSave": true,
        "editor.tabSize": 4,
        "files.autoSave": "onFocusChange",
        "kotlin.languageServer.enabled": true,
        "java.configuration.runtimes": [
          { "name": "JavaSE-17", "default": true }
        ]
      }
    }
  },
  "forwardPorts": [],
  "remoteEnv": {
    "ANDROID_HOME": "${localEnv:HOME}/android-sdk",
    "ANDROID_SDK_ROOT": "${localEnv:HOME}/android-sdk"
  }
}
EOF

# Install extensions if code CLI is available
if command -v code &>/dev/null; then
    log "Installing VS Code extensions..."
    extensions=(
        "mathiasfrohlich.Kotlin"
        "fwcd.kotlin"
        "vscjava.vscode-java-pack"
        "eamodio.gitlens"
        "usernamehw.errorlens"
        "pkief.material-icon-theme"
    )
    for ext in "${extensions[@]}"; do
        code --install-extension "${ext}" --force 2>/dev/null && ok "Installed: ${ext}" || warn "Could not install: ${ext}"
    done
else
    warn "VS Code CLI not found — extensions listed in .devcontainer/devcontainer.json for next open"
fi

# ─── Verification ─────────────────────────────────────────────────────────────
section "✅ Verification"

echo ""
echo -e "${BOLD}Tool versions:${NC}"
java -version 2>&1 | head -1                             && ok "Java"
gradle --version 2>/dev/null | grep "^Gradle"            && ok "Gradle"
"${CMDTOOLS_DIR}/bin/sdkmanager" --version 2>/dev/null   && ok "sdkmanager"

echo ""
echo -e "${BOLD}SDK packages installed:${NC}"
"${CMDTOOLS_DIR}/bin/sdkmanager" --list_installed 2>/dev/null \
    | grep -E "^  (platforms|build-tools|platform-tools|extras)" \
    | awk '{print "  ✓ " $1}' || true

echo ""
echo -e "${BOLD}Project structure:${NC}"
tree "${HOME}/NotificationVault" -L 3 --dirsfirst 2>/dev/null \
    || find "${HOME}/NotificationVault" -maxdepth 3 -print | head -40

# ─── Done ─────────────────────────────────────────────────────────────────────
section "🎉 Setup Complete"

echo -e "${GREEN}${BOLD}"
echo "  Android development environment is ready!"
echo ""
echo "  Project location : ~/NotificationVault"
echo "  Android SDK      : ~/android-sdk"
echo "  Java version     : ${JAVA_VERSION}"
echo "  Gradle version   : ${GRADLE_VERSION}"
echo "  Min SDK          : API 31 (Android 12)"
echo "  Target SDK       : API 36 (Android 16)"
echo -e "${NC}"
echo -e "${YELLOW}${BOLD}Next steps:${NC}"
echo "  1. Reload your shell:  source ~/.bashrc"
echo "  2. Go to project:      cd ~/NotificationVault"
echo "  3. First build check:  ./gradlew assembleDebug"
echo "  4. Open in VS Code:    code ~/NotificationVault"
echo ""
echo -e "${CYAN}Happy coding! 🚀${NC}"
echo ""
