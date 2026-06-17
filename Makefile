default: run

TARGET = aarch64-linux-android
API_LEVEL = 33
OUTPUT_DIR = android/app/src/main/jniLibs/arm64-v8a
OUTPUT_LIB = $(OUTPUT_DIR)/libmain.so
BDW_GC_VERSION = 8.2.6

CRYSTAL_SRC = $(shell crystal env CRYSTAL_PATH | cut -d: -f2)
NDK_ROOT = $(wildcard /Users/*/Library/Android/sdk/ndk/30.*)
NDK_SYSROOT = $(NDK_ROOT)/toolchains/llvm/prebuilt/darwin-x86_64/sysroot
NDK_LIB_DIR = $(NDK_SYSROOT)/usr/lib/aarch64-linux-android/$(API_LEVEL)
NDK_CC = $(NDK_ROOT)/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android$(API_LEVEL)-clang

.PHONY: dev apk install run clean clean-full

build/libgc.a:
	@echo "build/libgc.a not found. Fetching and compiling Boehm GC for Android ARM64..."
	@mkdir -p build/deps
	curl -L https://github.com/ivmai/bdwgc/releases/download/v$(BDW_GC_VERSION)/gc-$(BDW_GC_VERSION).tar.gz | tar -xz -C build/deps
	cd build/deps/gc-$(BDW_GC_VERSION) && \
		CC="$(NDK_CC) --sysroot=$(NDK_SYSROOT)" \
		./configure --host=aarch64-linux-android --enable-static --disable-shared --disable-threads && \
		make -j$(shell sysctl -n hw.ncpu)
	cp build/deps/gc-$(BDW_GC_VERSION)/.libs/libgc.a ./build/libgc.a

$(OUTPUT_LIB): build/libgc.a
	@mkdir -p build
	@mkdir -p $(OUTPUT_DIR)

	CRYSTAL_PATH="$(CRYSTAL_SRC)/lib_c/$(TARGET):$(CRYSTAL_SRC)" \
	crystal build src/main.cr \
		--cross-compile \
		-Dno_debug \
		-p \
		--target=$(TARGET) \
		-o build/main.o

	$(NDK_CC) -shared \
		--sysroot=$(NDK_SYSROOT) \
		build/main.o \
		-L./build \
		-Wl,--whole-archive -lgc -Wl,--no-whole-archive \
		$(NDK_LIB_DIR)/liblog.so \
		-o $(OUTPUT_LIB)

apk: $(OUTPUT_LIB)
	cd android && ./gradlew assembleDebug

install: apk
	cd android && ./gradlew installDebug

run: install
	adb shell am start -n com.mswieboda.hello/android.app.NativeActivity

# don't do build/libgc.a
clean:
	rm -rf $(OUTPUT_LIB)
	rm -rf $(OUTPUT_DIR)
	cd android && ./gradlew clean

clean-full: clean
	rm -rf build
