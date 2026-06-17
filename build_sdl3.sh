#!/bin/bash
set -e

# If SDL3_EXTERNAL is not provided in the environment, default to local path
# but still ensure the path actually exists.
SDL_SOURCE_PATH=${SDL3_EXTERNAL:-$HOME/ext_libs/SDL}

if [ ! -d "$SDL_SOURCE_PATH" ]; then
  echo "Error: SDL3 source not found at $SDL_SOURCE_PATH"
  echo "Please set the SDL3_EXTERNAL environment variable."
  exit 1
fi

# Define your local variables here or pass them in
BUILD_DIR="build/sdl3"
INSTALL_DIR="build/sdl3_install"

mkdir -p $BUILD_DIR

echo "Configuring SDL3 for Android..."
cmake -S $SDL_SOURCE_PATH \
  -B $BUILD_DIR \
  -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-33 \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
  -DSDL_SHARED=ON \
  -DSDL_STATIC=OFF

echo "Building SDL3 for Android..."
cmake --build $BUILD_DIR --parallel 4
echo "Installing SDL3 for Android..."
cmake --install $BUILD_DIR
