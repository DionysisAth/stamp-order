#!/usr/bin/env bash
# Prepares a GitHub Ubuntu runner to export the Android build: installs the
# SDK packages Godot needs, creates a debug keystore and points Godot's
# editor settings at the SDK, the JDK and the keystore.
set -euo pipefail

sdk="${ANDROID_HOME:?ANDROID_HOME must point at the Android SDK}"
java_home="${JAVA_HOME:?JAVA_HOME must point at a JDK 17}"
godot_minor="$(echo "${GODOT_VERSION:?}" | cut -d. -f1-2)"

sdkmanager="$sdk/cmdline-tools/latest/bin/sdkmanager"
yes | "$sdkmanager" --licenses > /dev/null || true
"$sdkmanager" --install "platform-tools" "build-tools;35.0.1" "platforms;android-35" > /dev/null

keystore="$HOME/.android/debug.keystore"
mkdir -p "$(dirname "$keystore")"
if [ ! -f "$keystore" ]; then
  keytool -genkeypair -keystore "$keystore" -storepass android -alias androiddebugkey \
    -keypass android -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=Android Debug,O=Android,C=US" > /dev/null
fi

mkdir -p "$HOME/.config/godot"
cat > "$HOME/.config/godot/editor_settings-${godot_minor}.tres" <<SETTINGS
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$sdk"
export/android/java_sdk_path = "$java_home"
export/android/debug_keystore = "$keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
SETTINGS

{
  echo "GODOT_ANDROID_KEYSTORE_DEBUG_PATH=$keystore"
  echo "GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey"
  echo "GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android"
} >> "${GITHUB_ENV:-/dev/null}"
echo "Android export configured (SDK: $sdk, JDK: $java_home)"
