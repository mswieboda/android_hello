default: run
.PHONY: ensure_sources dev apk install run clean clean-libs clean-all nuke

TARGET = aarch64-linux-android
API_LEVEL = 33
OUTPUT_DIR = android/app/src/main/jniLibs/arm64-v8a
OUTPUT_LIB = $(OUTPUT_DIR)/libmain.so

CRYSTAL_SRC = $(shell crystal env CRYSTAL_PATH | cut -d: -f2)
NDK_ROOT = $(wildcard /Users/*/Library/Android/sdk/ndk/30.*)
NDK_SYSROOT = $(NDK_ROOT)/toolchains/llvm/prebuilt/darwin-x86_64/sysroot
NDK_LIB_DIR = $(NDK_SYSROOT)/usr/lib/aarch64-linux-android/$(API_LEVEL)
NDK_CC = $(NDK_ROOT)/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android$(API_LEVEL)-clang

# Define the path to the vcpkg-built library
VCPKG_LIB_PATH = /Users/matt/ext_libs/vcpkg/installed/arm64-android/lib

# Define local source staging areas inside the build folder
SDL3_SRC_DIR       = build/src/SDL
SDL3_IMAGE_SRC_DIR = build/src/SDL_image
SDL3_MIXER_SRC_DIR = build/src/SDL_mixer
SDL3_TTF_SRC_DIR   = build/src/SDL_ttf

# These stay static and tied to project's build/sdl3_install
SDL3_INSTALL_DIR   = build/sdl3_install
SDL3_INC           = $(SDL3_INSTALL_DIR)/include
SDL3_LIB           = $(SDL3_INSTALL_DIR)/lib/libSDL3.so
SDL3_IMAGE_LIB     = $(SDL3_INSTALL_DIR)/lib/libSDL3_image.so
SDL3_MIXER_LIB     = $(SDL3_INSTALL_DIR)/lib/libSDL3_mixer.so
SDL3_TTF_LIB       = $(SDL3_INSTALL_DIR)/lib/libSDL3_ttf.so

$(SDL3_LIB):
	@# 1. Run the safe, microsecond-fast directory check right here inline
	@mkdir -p build/src
	@if [ ! -d "build/src/SDL" ]; then \
		echo "Cloning Core SDL3..."; \
		git clone --depth 1 --recursive -b main https://github.com/libsdl-org/SDL.git build/src/SDL; \
	fi
	@if [ ! -d "build/src/SDL_image" ]; then \
		echo "Cloning SDL_image..."; \
		git clone --depth 1 --recursive -b main https://github.com/libsdl-org/SDL_image.git build/src/SDL_image; \
	fi
	@if [ ! -d "build/src/SDL_mixer" ]; then \
		echo "Cloning SDL_mixer..."; \
		git clone --depth 1 --recursive -b main https://github.com/libsdl-org/SDL_mixer.git build/src/SDL_mixer; \
	fi
	@if [ ! -d "build/src/SDL_ttf" ]; then \
		echo "Cloning SDL_ttf..."; \
		git clone --depth 1 --recursive -b main https://github.com/libsdl-org/SDL_ttf.git build/src/SDL_ttf; \
	fi

	@echo "Building SDL3 libs..."
	@./build_sdl3.sh

# extension libs are created as a side-effect of building core
$(SDL3_IMAGE_LIB) $(SDL3_MIXER_LIB) $(SDL3_TTF_LIB): $(SDL3_LIB)
	@# Intentional comment placeholder.
	@# This tells Make: "Go check/run the $(SDL3_LIB) target to get these files."

build/libgc.a:
	@mkdir -p build
	@echo "Install libgc library from vcpkg..."
	vcpkg install bdwgc:arm64-android
	cp $(VCPKG_LIB_PATH)/libgc.a build/libgc.a

build/bridge.o: src/bridge.c $(SDL3_LIB)
	@mkdir -p build
	@echo "Compiling C bridge with SDL3 entry points..."
	$(NDK_CC) --sysroot=$(NDK_SYSROOT) \
		-c src/bridge.c \
		-I$(SDL3_INC) \
		-o build/bridge.o

build/main.o: src/main.cr
	@mkdir -p build
	@echo "Compiling crystal..."
	CRYSTAL_PATH="$(CRYSTAL_SRC)/lib_c/$(TARGET):$(CRYSTAL_SRC):$(CURDIR)/lib" \
	crystal build src/main.cr \
		--cross-compile \
		-Dno_debug \
		-p \
		--target=$(TARGET) \
		-o build/main.o

# Add the new libraries to the dependency line
$(OUTPUT_LIB): build/bridge.o build/libgc.a $(SDL3_LIB) $(SDL3_IMAGE_LIB) $(SDL3_MIXER_LIB) $(SDL3_TTF_LIB) build/main.o
	@mkdir -p $(OUTPUT_DIR)
	@echo "Compiling NDK combo..."
	$(NDK_CC) -shared \
		--sysroot=$(NDK_SYSROOT) \
		build/main.o \
		build/bridge.o \
		-L./build \
		-L$(SDL3_INSTALL_DIR)/lib \
		-lSDL3 \
		-lSDL3_image \
		-lSDL3_mixer \
		-lSDL3_ttf \
		-Wl,--whole-archive -lgc -Wl,--no-whole-archive \
		$(NDK_LIB_DIR)/liblog.so \
		-landroid \
		-o $(OUTPUT_LIB)

	@echo "Copying all SDL3 binaries to output directory..."
	find $(SDL3_INSTALL_DIR)/lib -name "*.so" -type f -exec cp {} $(OUTPUT_DIR)/ \;

dev: $(OUTPUT_LIB)

apk: dev
	cd android && ./gradlew assembleDebug

install: apk
	cd android && ./gradlew installDebug

run:
	adb shell am start -n com.mswieboda.hello/com.mswieboda.hello.MainActivity

# Standard clean: Fast, safe, preserves ALL cache, downloads, and compiled libraries.
# Run this when you just want to recompile your game logic.
clean:
	@echo "Cleaning game build artifacts..."
	rm -f build/main.o build/bridge.o
	rm -rf $(OUTPUT_LIB)
	rm -rf $(OUTPUT_DIR)
	@if [ -d "android" ]; then cd android && ./gradlew clean; fi

# Intermediate clean: Cleans our compiled library targets but leaves source code intact.
# Run this if you want to force CMake to re-compile SDL3/Extensions from source.
clean-libs:
	@echo "Cleaning compiled dependencies..."
	rm -rf build/sdl3 build/sdl_image build/sdl_mixer build/sdl_ttf
	rm -rf build/sdl3_install
	rm -f build/libgc.a

# The Ultimate Option: Safely cleans everything EXCEPT the massive git download sources.
# Preserves vcpkg downloads and git clones so you don't face long network delays.
clean-all: clean clean-libs

# Nuke: Explicit, managed destruction.
# Completely resets the workspace back to a pristine checkout state.
nuke:
	@echo "⚠️ WARNING: Nuking all build directories, caches, and downloaded sources..."
	@echo "Press Ctrl+C inside 3 seconds to abort..." && sleep 3
	rm -rf build
	rm -rf android/.gradle android/app/build
