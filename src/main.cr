# src/main.cr

lib LibAndroidLog
  # Bind directly to the NDK log library
  fun write = __android_log_write(prio : Int32, tag : UInt8*, text : UInt8*) : Int32
end

# Expose the mandatory NativeActivity entry point directly to the C linker
fun aNativeActivity_onCreate = ANativeActivity_onCreate(
  activity : Void*,
  saved_state : Void*,
  saved_state_size : LibC::SizeT
) : Void

  # Write directly to logcat using basic pointers, completely skipping
  # standard string allocations until we initialize the GC heap later.
  LibAndroidLog.write(4, "CrystalGame".to_unsafe, "Hello from bare-metal Crystal on Android!".to_unsafe)
end
