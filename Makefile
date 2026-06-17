default: run
.PHONY: dev apk install run clean clean-libgc clean-sdl3

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

# GLUE_SRC = $(NDK_ROOT)/sources/android/native_app_glue/android_native_app_glue.c
GLUE_INC = $(NDK_ROOT)/sources/android/native_app_glue

SDL3_INSTALL_DIR = build/sdl3_install
SDL3_LIB = $(SDL3_INSTALL_DIR)/lib/libSDL3.so
SDL3_INC = $(SDL3_INSTALL_DIR)/include

SDL3_SRC_DIR = /Users/matt/ext_libs/SDL
JAVA_TARGET_DIR = android/app/src/main/java/org/libsdl/app

$(SDL3_LIB):
	@echo "Building SDL3..."
	./build_sdl3.sh

sync-sdl-java:
	@echo "Copying SDL3 Java source files..."
	@mkdir -p $(JAVA_TARGET_DIR)
	@cp -R $(SDL3_SRC_DIR)/android-project/app/src/main/java/org/libsdl/app/. $(JAVA_TARGET_DIR)/

# build/android_native_app_glue.o:
# 	@echo "Compiling native_app_glue..."
# 	$(NDK_CC) --sysroot=$(NDK_SYSROOT) \
# 		-c $(GLUE_SRC) -I$(GLUE_INC) \
# 		-o build/android_native_app_glue.o

build/libgc.a:
	@mkdir -p build
	@echo "Install libgc library from vcpkg..."
	vcpkg install bdwgc:arm64-android
	cp $(VCPKG_LIB_PATH)/libgc.a build/libgc.a

# build/bridge.o: src/bridge.c
# 	$(NDK_CC) --sysroot=$(NDK_SYSROOT) \
# 		-c src/bridge.c -I$(GLUE_INC) \
# 		-o build/bridge.o
build/bridge.o: src/bridge.c $(SDL3_LIB)
	@mkdir -p build
	@echo "Compiling C bridge with SDL3 entry points..."
	$(NDK_CC) --sysroot=$(NDK_SYSROOT) \
		-c src/bridge.c \
		-I$(GLUE_INC) \
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

# $(OUTPUT_LIB): build/android_native_app_glue.o build/bridge.o build/libgc.a $(SDL3_LIB) build/main.o
# build/android_native_app_glue.o (was added to list below after build/main.o)
$(OUTPUT_LIB): build/bridge.o build/libgc.a $(SDL3_LIB) build/main.o
	@mkdir -p $(OUTPUT_DIR)
	@echo "Compiling NDK combo..."
	$(NDK_CC) -shared \
		--sysroot=$(NDK_SYSROOT) \
		build/main.o \
		build/bridge.o \
		-L./build \
		-L$(SDL3_INSTALL_DIR)/lib \
		-lSDL3 \
		-Wl,--whole-archive -lgc -Wl,--no-whole-archive \
		$(NDK_LIB_DIR)/liblog.so \
		-landroid \
		-o $(OUTPUT_LIB)
	cp $(SDL3_LIB) $(OUTPUT_DIR)/

dev: $(OUTPUT_LIB)

apk: dev sync-sdl-java
	cd android && ./gradlew assembleDebug

install: apk
	cd android && ./gradlew installDebug

run: install
	adb shell am start -n com.mswieboda.hello/org.libsdl.app.SDLActivity
# 	adb shell am start -n com.mswieboda.hello/android.app.NativeActivity

# don't do build/libgc.a
clean:
	rm -rf $(OUTPUT_LIB)
	rm -rf $(OUTPUT_DIR)
	cd android && ./gradlew clean

clean-libgc:
	rm -rf build/libgc.a

clean-sdl3:
	rm -rf build/sdl3
	rm -rf build/sdl3_install

