#!/usr/bin/env bash
# Build Kurage's Linux AppImage in a disposable Arch Linux Podman container.
# Run from the root of the Kurage checkout on an x86_64 Linux host.
set -euo pipefail

if [[ "${KURAGE_APPIMAGE_CONTAINER:-0}" != 1 ]]; then
  [[ -f pubspec.yaml && -f build-kurage-anylinux-appimage.sh ]] || {
    echo 'Run this script from the root of the Kurage checkout.' >&2
    exit 1
  }
  command -v podman >/dev/null || { echo 'Podman is required on the host.' >&2; exit 1; }
  [[ "$(uname -m)" == x86_64 ]] || { echo 'Only x86_64 is supported.' >&2; exit 1; }
  tty=(-i)
  [[ -t 0 && -t 1 ]] && tty=(-it)
  exec podman run --rm "${tty[@]}" \
    -v "$(pwd -P):/src" -w /src -e HOME=/tmp \
    -e KURAGE_APPIMAGE_CONTAINER=1 \
    -e "UPDATE_SONY=${UPDATE_SONY:-0}" \
    -e "REBUILD_SONY=${REBUILD_SONY:-0}" \
    -e "SKIP_FLUTTER_BUILD=${SKIP_FLUTTER_BUILD:-0}" \
    docker.io/library/archlinux:latest \
    bash ./build-kurage-anylinux-appimage.sh
fi

cd /src
ROOT=$PWD
BUNDLE="$ROOT/build/elinux-kurage"
WORK="$ROOT/build/appimage"
TOOLCHAINS="$ROOT/build/toolchains"
SONY_SOURCE="$ROOT/build/sony-embedder"
SONY_REPO='https://github.com/lkcv/flutter-embedded-linux.git'
SONY_STAMP="$BUNDLE/.sony-build-revision"
FLUTTER_TAG=3.50.0
FLUTTER_ENGINE_REV=371f77202a73e8dff57a8b3bff75bca55c090aee
FLUTTER_SDK="$TOOLCHAINS/flutter"
ENGINE_DIR="$TOOLCHAINS/engine/$FLUTTER_ENGINE_REV"
ENGINE_LIB="$ENGINE_DIR/libflutter_engine.so"
ENGINE_ASSET="linux-engine-sdk-release-x86_64-${FLUTTER_ENGINE_REV}.tar.gz"
ENGINE_URL="https://github.com/meta-flutter/flutter-engine/releases/download/linux-engine-sdk-release-x86_64-${FLUTTER_ENGINE_REV}/${ENGINE_ASSET}"
ENGINE_SHA256=78c67589f7ad110f61dbcf16dee14494d05b72f4c8480b7e4a4bec20868b67c9
ISAR_VERSION=3.4.1
ISAR_SHA256=f28dd092cd322629efd58598581287eaf8687a8f9522cf9d12ceda2aa57b4fc0
VERSION="$(awk '/^version: / {sub(/\+.*/, "", $2); print $2; exit}' pubspec.yaml)"
[[ -n "$VERSION" ]] || { echo 'Missing version in pubspec.yaml.' >&2; exit 1; }

export APPDIR="$WORK/Kurage.AppDir"
export OUTPATH="$WORK/dist"
export OUTNAME="Kurage-${VERSION}-$(uname -m).AppImage"
export DESKTOP="$WORK/com.lkcv.kurage.desktop"
SOURCE_ICON="$ROOT/fastlane/metadata/android/en-US/images/icon.png"
export ICON="$WORK/kurage.png"
export MAIN_BIN=flutter-client
export USE_HOST_DRIVERS=1
# This container has no Wayland compositor for runtime dependency tracing.
export STRACE_MODE=0
# Flutter's archives must not attempt to chown files inside rootless Podman.
export TAR_OPTIONS=--no-same-owner
export PUB_CACHE="$ROOT/build/.pub-cache"

# All OS packages are installed inside the disposable container.
pacman -Syu --needed --noconfirm \
  base-devel git curl wget unzip xz zip tar file python which \
  clang cmake ninja pkgconf gtk3 libsecret \
  wayland wayland-protocols libxkbcommon libglvnd \
  patchelf binutils
mkdir -p "$TOOLCHAINS" "$WORK" "$PUB_CACHE"

# A fixed Flutter SDK release and a matching raw release engine are essential:
# an AOT libapp.so cannot safely be paired with an unrelated engine revision.
if [[ ! -x "$FLUTTER_SDK/bin/flutter" ]]; then
  [[ ! -e "$FLUTTER_SDK" ]] || {
    echo "Incomplete Flutter checkout: $FLUTTER_SDK" >&2; exit 1;
  }
  git clone --depth 1 --branch "$FLUTTER_TAG" \
    https://github.com/flutter/flutter.git "$FLUTTER_SDK"
fi
[[ "$(cat "$FLUTTER_SDK/bin/internal/engine.version")" == "$FLUTTER_ENGINE_REV" ]] || {
  echo "Flutter SDK and engine revision mismatch (expected $FLUTTER_ENGINE_REV)." >&2
  exit 1
}
export PATH="$FLUTTER_SDK/bin:$PATH"
flutter config --no-analytics --enable-linux-desktop

# Download the raw engine from the matching meta-flutter release, verify its
# published digest, and cache the extracted .so for later Podman runs.
if [[ ! -f "$ENGINE_LIB" ]]; then
  ARCHIVE="$TOOLCHAINS/$ENGINE_ASSET"
  if [[ ! -f "$ARCHIVE" ]]; then
    curl -fL --retry 3 "$ENGINE_URL" -o "$ARCHIVE"
  fi
  echo "$ENGINE_SHA256  $ARCHIVE" | sha256sum -c -
  UNPACK="$TOOLCHAINS/engine/unpack-$FLUTTER_ENGINE_REV"
  rm -rf "$UNPACK"
  mkdir -p "$UNPACK" "$ENGINE_DIR"
  tar -xzf "$ARCHIVE" -C "$UNPACK"
  ENGINE_FOUND="$(find "$UNPACK" -name libflutter_engine.so -print -quit)"
  [[ -n "$ENGINE_FOUND" && -f "$ENGINE_FOUND" ]] || {
    echo 'Downloaded engine SDK does not contain libflutter_engine.so.' >&2
    exit 1
  }
  install -Dm755 "$ENGINE_FOUND" "$ENGINE_LIB"
  rm -rf "$UNPACK"
fi

# Clone the published Sony fork into Kurage's git-ignored build tree.
if ! git -C "$SONY_SOURCE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  [[ ! -e "$SONY_SOURCE" ]] || {
    echo "Sony source directory is not a Git checkout: $SONY_SOURCE" >&2; exit 1;
  }
  git clone "$SONY_REPO" "$SONY_SOURCE"
fi
if [[ "${UPDATE_SONY:-0}" == 1 ]]; then
  [[ -z "$(git -C "$SONY_SOURCE" status --porcelain)" ]] || {
    echo 'Sony checkout has local changes; refusing to update.' >&2; exit 1;
  }
  git -C "$SONY_SOURCE" pull --ff-only origin master
fi
[[ -f "$SONY_SOURCE/build-wayland.sh" ]] || {
  echo 'Sony fork is missing build-wayland.sh.' >&2; exit 1;
}
if [[ ! -f "$SONY_SOURCE/build/libflutter_engine.so" ]] || \
   ! cmp -s "$ENGINE_LIB" "$SONY_SOURCE/build/libflutter_engine.so"; then
  install -Dm755 "$ENGINE_LIB" "$SONY_SOURCE/build/libflutter_engine.so"
fi

SONY_REV="$(git -C "$SONY_SOURCE" rev-parse HEAD)"
[[ -z "$(git -C "$SONY_SOURCE" status --porcelain)" ]] || SONY_REV="${SONY_REV}-dirty"
ENGINE_HASH="$(sha256sum "$ENGINE_LIB" | cut -d' ' -f1)"
SONY_BUILD_ID="${SONY_REV}-release-vsync-${ENGINE_HASH}"
if [[ ! -x "$BUNDLE/flutter-client" || ! -f "$BUNDLE/lib/libflutter_engine.so" || \
      ! -f "$SONY_STAMP" || "$(cat "$SONY_STAMP" 2>/dev/null)" != "$SONY_BUILD_ID" || \
      "$SONY_REV" == *-dirty || "${REBUILD_SONY:-0}" == 1 ]]; then
  bash "$SONY_SOURCE/build-wayland.sh"
  install -Dm755 "$SONY_SOURCE/build/flutter-client" "$BUNDLE/flutter-client"
  install -Dm755 "$ENGINE_LIB" "$BUNDLE/lib/libflutter_engine.so"
  printf '%s\n' "$SONY_BUILD_ID" > "$SONY_STAMP"
else
  echo 'Reusing the Sony Wayland runner.'
fi

if [[ "${SKIP_FLUTTER_BUILD:-0}" != 1 ]]; then
  flutter build linux --release
fi
FLUTTER_BUNDLE="$ROOT/build/linux/x64/release/bundle"
[[ -f "$FLUTTER_BUNDLE/lib/libapp.so" && -d "$FLUTTER_BUNDLE/data" ]] || {
  echo "Missing Flutter release bundle: $FLUTTER_BUNDLE" >&2; exit 1;
}
install -Dm755 "$FLUTTER_BUNDLE/lib/libapp.so" "$BUNDLE/lib/libapp.so"
rm -rf "$BUNDLE/data"
cp -a "$FLUTTER_BUNDLE/data" "$BUNDLE/data"

for path in \
  "$BUNDLE/flutter-client" \
  "$BUNDLE/lib/libflutter_engine.so" \
  "$BUNDLE/lib/libapp.so" \
  "$BUNDLE/data/flutter_assets" \
  "$SOURCE_ICON"; do
  [[ -e "$path" ]] || { echo "Missing bundle component: $path" >&2; exit 1; }
done

# Isar is loaded through Dart FFI rather than through an ELF DT_NEEDED entry.
# Always use the version pinned in pubspec.lock.
LOCKED_ISAR="$(awk '/^  isar_community:$/ {found=1; next} found && /^  [^ ]/ {exit} found && /version:/ {gsub(/"/, "", $2); print $2; exit}' pubspec.lock)"
[[ "$LOCKED_ISAR" == "$ISAR_VERSION" ]] || {
  echo "Isar lockfile version '$LOCKED_ISAR' differs from pinned native $ISAR_VERSION." >&2
  exit 1
}
ISAR_LIB="$TOOLCHAINS/libisar-${ISAR_VERSION}.so"
if [[ ! -f "$ISAR_LIB" ]]; then
  curl -fL --retry 3 \
    "https://github.com/isar-community/isar-community/releases/download/${ISAR_VERSION}/libisar_linux_x64.so" \
    -o "$ISAR_LIB"
fi
echo "$ISAR_SHA256  $ISAR_LIB" | sha256sum -c -

# quick-sharun deploys dependencies from standard /usr paths. All copies and
# package installations happen only inside the ephemeral container.
install -Dm755 "$BUNDLE/flutter-client" /usr/bin/flutter-client
install -Dm755 "$BUNDLE/lib/libflutter_engine.so" /usr/lib/libflutter_engine.so
install -Dm755 "$BUNDLE/lib/libapp.so" /usr/lib/libapp.so
install -Dm755 "$ISAR_LIB" /usr/lib/libisar.so

rm -rf "$APPDIR"
mkdir -p "$APPDIR" "$OUTPATH"
install -Dm644 "$SOURCE_ICON" "$ICON"
cp -a "$BUNDLE/data" "$APPDIR/data"

cat > "$DESKTOP" <<'DESKTOP_EOF'
[Desktop Entry]
Type=Application
Name=Kurage
Comment=Jellyfin comic reader
Exec=flutter-client
Icon=kurage
Terminal=false
Categories=Graphics;Viewer;
StartupWMClass=com.lkcv.kurage
DESKTOP_EOF

# Retain Sony's Flutter project bundle layout and the existing working
# --async-vblank flag. Sharun supplies APPDIR and dependency hooks.
cat > "$APPDIR/AppRun.sh" <<'APPRUN_EOF'
#!/bin/sh
set -e
export PATH="$APPDIR/bin:$PATH"
if [ -f "$APPDIR/AppRun.lib" ]; then
  . "$APPDIR/AppRun.lib"
  for hook in "$APPDIR"/bin/*.hook; do
    [ -f "$hook" ] || continue
    . "$hook"
  done
fi
exec "$APPDIR/bin/flutter-client" \
  --bundle="$APPDIR" \
  --title=Kurage \
  --app-id=com.lkcv.kurage \
  --width=1100 \
  --height=800 \
  --async-vblank \
  "$@"
APPRUN_EOF
chmod +x "$APPDIR/AppRun.sh"

SHARUN="$WORK/quick-sharun.sh"
curl -fL --retry 3 \
  https://raw.githubusercontent.com/pkgforge-dev/Anylinux-AppImages/main/useful-tools/quick-sharun.sh \
  -o "$SHARUN"
chmod +x "$SHARUN"
"$SHARUN" \
  /usr/bin/flutter-client \
  /usr/lib/libflutter_engine.so \
  /usr/lib/libapp.so \
  /usr/lib/libisar.so

for path in \
  "$APPDIR/bin/flutter-client" \
  "$APPDIR/lib/libflutter_engine.so" \
  "$APPDIR/lib/libapp.so" \
  "$APPDIR/lib/libisar.so" \
  "$APPDIR/data/flutter_assets" \
  "$APPDIR/AppRun"; do
  [[ -e "$path" ]] || { echo "Missing AppImage component: $path" >&2; exit 1; }
done

"$SHARUN" --make-appimage
printf '\nAppImage created: %s/%s\n' "$OUTPATH" "$OUTNAME"
