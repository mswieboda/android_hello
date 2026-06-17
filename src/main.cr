lib LibAndroidLog
  # Bind directly to the NDK log library
  fun write = __android_log_write(prio : Int32, tag : UInt8*, text : UInt8*) : Int32
end

def android_log(message : String)
  # Write directly to logcat using basic pointers, completely skipping
  # standard string allocations until we initialize the GC heap later.
  LibAndroidLog.write(4, "CrystalGame".to_unsafe, ">>> #{message}".to_unsafe)
end

@[Link("android")]
lib LibAndroid
  # The value is defined as 1 in the NDK
  LOOPER_ID_MAIN = 1
  LOOPER_ID_INPUT = 2

  # ALooper_pollAll arguments:
  # timeoutMillis: Int32 (-1 to wait indefinitely)
  # outFd: Int32* (returns the file descriptor, or nil if not needed)
  # outEvents: Int32* (returns the events, or nil if not needed)
  # outData: Void** (returns the data pointer, or nil if not needed)
  fun a_looper_poll_all = ALooper_pollAll(
    timeoutMillis : Int32,
    outFd : Int32*,
    outEvents : Int32*,
    outData : Void**
  ) : Int32
end

@[Extern]
struct AndroidApp
  # Pointer to the activity, looper, etc.
  reserved : Void* # This is the flag we need!
  destroyRequested : Int32

  # You will eventually need to add more fields here
  # like 'window' or 'config' as you progress.
end

@[Packed]
@[Extern]
struct AndroidPollSource
  id : Int32
  app : Void*
  process : (Void*, Void*) -> Void
end

# This doesn't need @[Link] because you are linking the .o file
lib LibAndroidGlue
  fun android_app_read_cmd = android_app_read_cmd(app : Void*) : Int8
  fun android_app_pre_exec_cmd = android_app_pre_exec_cmd(app : Void*, cmd : Int8)
  fun android_app_post_exec_cmd = android_app_post_exec_cmd(app : Void*, cmd : Int8)
end

# Bind the C helper functions
lib LibAndroidHelper
  fun is_destroy_requested = is_destroy_requested(app : Void*) : Int32
  fun get_poll_source_process_func(source : Void*) : Void*
  fun call_process_func(source : Void*, app : Void*)
end

fun android_main(app_ptr : Void*)
  # Cast the Void* to an AndroidApp*
  app = app_ptr.as(AndroidApp*)

  # Variables to hold the output from the poll function
  out_fd = 0
  out_events = 0
  source_data = pointerof(out_fd) # Just placeholders for the poll

  # heartbeat
  counter = 0

  android_log("android_main reached. Starting event loop...")

  loop do
    # 'ident' tells us which source (e.g., input, command pipe) has an event
    # 'timeout' is in milliseconds.
    # Use -1 to wait forever, or a small number (e.g., 16ms for 60fps)
    # to wake up periodically.
    source_ptr = uninitialized Void*

    loop do
      # 16ms timeout (~60 FPS)
      ident = LibAndroid.a_looper_poll_all(16, nil, nil, pointerof(source_ptr))
      break if ident < 0 # No more events

      # If it's a command, read it
      if ident == LibAndroid::LOOPER_ID_MAIN
        cmd = LibAndroidGlue.android_app_read_cmd(app_ptr)

        android_log("processing cmd: #{cmd}")

        if cmd >= 0
          LibAndroidGlue.android_app_pre_exec_cmd(app_ptr, cmd)

          # Handle the commands
          case cmd
          when 0 # APP_CMD_INIT_WINDOW
            android_log("Window is initialized! We can draw now.")
          when 2 # APP_CMD_RESUME
            android_log("App resumed.")
          end

          LibAndroidGlue.android_app_post_exec_cmd(app_ptr, cmd)
        end
      end
    end

    # Only increment/log here, outside the command processing loop
    # android_log("check for heartbeat, counter: #{counter}")
    counter += 1
    if counter % 100 == 0
      android_log("heartbeat, counter: #{counter}")
    end

    # android_log("check to exit: #{LibAndroidHelper.is_destroy_requested(app)}")
    # Check if we should exit
    break if LibAndroidHelper.is_destroy_requested(app) != 0
  end
end
