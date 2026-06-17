#!/bin/bash
set -e

# Core source roots now default directly to your self-contained build layout
SDL_SRC_ROOT=${SDL3_EXTERNAL:-"build/src/SDL"}
SDL_IMAGE_SRC_ROOT=${SDL3_IMAGE_EXTERNAL:-"build/src/SDL_image"}
SDL_MIXER_SRC_ROOT=${SDL3_MIXER_EXTERNAL:-"build/src/SDL_mixer"}
SDL_TTF_SRC_ROOT=${SDL3_TTF_EXTERNAL:-"build/src/SDL_ttf"}

# Verify source directories exist before starting
for dir in "$SDL_SRC_ROOT" "$SDL_IMAGE_SRC_ROOT" "$SDL_MIXER_SRC_ROOT" "$SDL_TTF_SRC_ROOT"; do
  if [ ! -d "$dir" ]; then
    echo "Error: Directory target not found at $dir"
    echo "Expected source files inside build/src/. Did ensure_sources run?"
    exit 1
  fi
done

# Define build and install targets inside your project workspace
INSTALL_DIR="$(pwd)/build/sdl3_install"
JNILIBS_DIR="$(pwd)/android/app/src/main/jniLibs/arm64-v8a"
JAVA_TARGET_DIR="$(pwd)/android/app/src/main/java/org/libsdl/app"

mkdir -p "$INSTALL_DIR"
mkdir -p "$JNILIBS_DIR"
mkdir -p "$JAVA_TARGET_DIR"

# -----------------------------------------------------------------------------
# 1. SYNC SDL3 JAVA SOURCE FILES TO ANDROID APP
# -----------------------------------------------------------------------------
echo "=== Syncing SDL3 Java source files from source path ==="
cp -R "$SDL_SRC_ROOT/android-project/app/src/main/java/org/libsdl/app/." "$JAVA_TARGET_DIR/"

# Common toolchain flags shared across all builds
COMMON_ARGS=(
  "-DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake"
  "-DANDROID_ABI=arm64-v8a"
  "-DANDROID_PLATFORM=android-33"
  "-DCMAKE_BUILD_TYPE=Release"
  "-DCMAKE_INSTALL_PREFIX=$INSTALL_DIR"
  "-DCMAKE_FIND_ROOT_PATH=$INSTALL_DIR"
  "-DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH"
)

# -----------------------------------------------------------------------------
# 2. BUILD CORE SDL3
# -----------------------------------------------------------------------------
echo "=== Configuring & Building Core SDL3 ==="
cmake -S "$SDL_SRC_ROOT" -B build/sdl3 \
  "${COMMON_ARGS[@]}" \
  -DSDL_SHARED=ON \
  -DSDL_STATIC=OFF

cmake --build build/sdl3 --parallel 4
cmake --install build/sdl3

# -----------------------------------------------------------------------------
# 3. BUILD SDL_IMAGE
# -----------------------------------------------------------------------------
echo "=== Configuring & Building SDL_image ==="
cmake -S "$SDL_IMAGE_SRC_ROOT" -B build/sdl_image \
  "${COMMON_ARGS[@]}" \
  -DCMAKE_PREFIX_PATH="$INSTALL_DIR" \
  -DSDLIMAGE_VENDORED=ON \
  -DSDLIMAGE_SAMPLES=OFF \
  -DSDLIMAGE_TESTS=OFF \
  -DBUILD_SHARED_LIBS=ON

cmake --build build/sdl_image --parallel 4
cmake --install build/sdl_image

# -----------------------------------------------------------------------------
# 4. BUILD SDL_MIXER
# -----------------------------------------------------------------------------
echo "=== Configuring & Building SDL_mixer ==="
cmake -S "$SDL_MIXER_SRC_ROOT" -B build/sdl_mixer \
  "${COMMON_ARGS[@]}" \
  -DCMAKE_PREFIX_PATH="$INSTALL_DIR" \
  -DSDLMIXER_VENDORED=ON \
  -DSDLMIXER_SAMPLES=OFF \
  -DSDLMIXER_TESTS=OFF \
  -DSDLMIXER_OPUS=OFF \
  -DSDLMIXER_FLAC=OFF \
  -DBUILD_SHARED_LIBS=ON

cmake --build build/sdl_mixer --parallel 4
cmake --install build/sdl_mixer

# -----------------------------------------------------------------------------
# 5. BUILD SDL_TTF
# -----------------------------------------------------------------------------
echo "=== Configuring & Building SDL_ttf ==="
cmake -S "$SDL_TTF_SRC_ROOT" -B build/sdl_ttf \
  "${COMMON_ARGS[@]}" \
  -DCMAKE_PREFIX_PATH="$INSTALL_DIR" \
  -DSDLTTF_VENDORED=ON \
  -DSDLTTF_SAMPLES=OFF \
  -DSDLTTF_TESTS=OFF \
  -DBUILD_SHARED_LIBS=ON

cmake --build build/sdl_ttf --parallel 4
cmake --install build/sdl_ttf

# -----------------------------------------------------------------------------
# 6. SYNC BINARIES TO JNILIBS
# -----------------------------------------------------------------------------
echo "=== Syncing compiled binaries to Android jniLibs ==="
cp "$INSTALL_DIR"/lib/*.so "$JNILIBS_DIR/"

echo "=== Success! All libraries and Java dependencies updated ==="
ls -lah "$JNILIBS_DIR"
