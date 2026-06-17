default: dev

TARGET = aarch64-linux-android
API_LEVEL = 33
OUTPUT_DIR = android/app/src/main/jniLibs/arm64-v8a
OUTPUT_LIB = $(OUTPUT_DIR)/libmain.so
CRYSTAL_SRC = $(shell crystal env CRYSTAL_PATH | cut -d: -f2)
NDK_ROOT = $(wildcard /Users/*/Library/Android/sdk/ndk/30.*)
NDK_SYSROOT = $(NDK_ROOT)/toolchains/llvm/prebuilt/darwin-x86_64/sysroot
NDK_LIB_DIR = $(NDK_SYSROOT)/usr/lib/aarch64-linux-android/$(API_LEVEL)

.PHONY: dev clean

dev:
	@mkdir -p build
	@mkdir -p $(OUTPUT_DIR)
	CRYSTAL_PATH="$(CRYSTAL_SRC)/lib_c/$(TARGET):$(CRYSTAL_SRC)" \
	crystal build src/main.cr \
		--cross-compile \
		-Dno_debug \
		-p \
		--target=$(TARGET) \
		-o build/main.o

	@echo "Linking against NDK_SYSROOT path: $(NDK_SYSROOT)"
	@echo "Directly linking file: $(NDK_LIB_DIR)/liblog.so"

	zig cc -shared \
		-target aarch64-linux-gnu \
		--sysroot=$(NDK_SYSROOT) \
		build/main.o \
		$(NDK_LIB_DIR)/liblog.so \
		-o $(OUTPUT_LIB)

clean:
	rm -rf build
	rm -rf $(OUTPUT_DIR)
