#!/usr/bin/env bash
# Read-only environment diagnostic for Cam-Anime. Installs and modifies nothing.
# Usage: scripts/check_env.sh   (share the full output when asking for help)

set -u

section() { printf '\n== %s ==\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }
ver() {
  local name="$1"; shift
  if have "$name"; then
    printf '%-12s %s\n' "$name" "$(command -v "$name")"
    "$@" 2>&1 | head -n 3 | sed 's/^/             /'
  else
    printf '%-12s MISSING\n' "$name"
  fi
}

section "OS / hardware"
(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release) | head -n 1
uname -srm
printf 'CPU cores: %s\n' "$(nproc)"
free -h | sed -n '1,2p'
df -h "$HOME" | sed -n '1,2p'

section "Core tools"
ver git git --version
ver curl curl --version
ver unzip unzip -v
ver xz xz --version
ver cmake cmake --version
ver ninja ninja --version
ver clang clang --version

section "Java (use JDK 17 for Gradle/AGP; see docs/development/DEVELOPMENT_SETUP.md)"
ver java java -version
ver javac javac -version
printf 'JAVA_HOME=%s\n' "${JAVA_HOME:-<unset>}"
ls /usr/lib/jvm 2>/dev/null | sed 's/^/  jvm: /'

section "Flutter / Dart"
ver flutter flutter --version
ver dart dart --version
if have flutter; then flutter config 2>&1 | grep -E 'jdk-dir|android-sdk' | sed 's/^/  /'; fi

section "Android SDK"
printf 'ANDROID_HOME=%s\n' "${ANDROID_HOME:-<unset>}"
printf 'ANDROID_SDK_ROOT=%s\n' "${ANDROID_SDK_ROOT:-<unset>}"
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
if [ -d "$SDK" ]; then
  printf 'SDK dir: %s\n' "$SDK"
  for d in platform-tools platforms build-tools ndk cmake cmdline-tools; do
    if [ -d "$SDK/$d" ]; then printf '  %-15s %s\n' "$d" "$(ls "$SDK/$d" | tr '\n' ' ')"; else printf '  %-15s MISSING\n' "$d"; fi
  done
else
  printf 'SDK dir not found at %s\n' "$SDK"
fi
ver adb adb version
ver sdkmanager sdkmanager --version

section "Android device (USB debugging)"
if have adb; then
  adb devices -l 2>&1
  if adb get-state >/dev/null 2>&1; then
    for p in ro.product.manufacturer ro.product.model ro.build.version.release ro.build.version.sdk ro.hardware ro.board.platform ro.product.cpu.abi; do
      printf '  %-28s %s\n' "$p" "$(adb shell getprop "$p" 2>/dev/null | tr -d '\r')"
    done
  fi
else
  echo "adb missing; cannot list devices"
fi
printf 'USB devices (lsusb):\n'; lsusb 2>/dev/null | sed 's/^/  /'
printf 'Groups: %s\n' "$(id -nG)"

section "Flutter doctor"
if have flutter; then flutter doctor -v 2>&1 | head -n 80; else echo "flutter missing; skipped"; fi

echo
echo "Done. Nothing was installed or changed."
