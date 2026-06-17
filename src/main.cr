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
  # NOTE: not working to map things, using the bridge helper for now
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
  enum AppCmd : Int32
    INPUT_CHANGED       = 0
    INIT_WINDOW         = 1
    TERM_WINDOW         = 2
    WINDOW_RESIZED      = 3
    WINDOW_REDRAW_NEEDED= 4
    CONTENT_RECT_CHANGED= 5
    GAINED_FOCUS        = 6
    LOST_FOCUS          = 7
    CONFIG_CHANGED      = 8
    LOW_MEMORY          = 9
    START               = 10
    RESUME              = 11
    SAVE_STATE          = 12
    PAUSE               = 13
    STOP                = 14
    DESTROY             = 15
  end

  fun android_app_read_cmd = android_app_read_cmd(app : Void*) : Int8
  fun android_app_pre_exec_cmd = android_app_pre_exec_cmd(app : Void*, cmd : Int8)
  fun android_app_post_exec_cmd = android_app_post_exec_cmd(app : Void*, cmd : Int8)
end

# Bind the C helper functions
lib LibAndroidHelper
  @[Packed]
  @[Extern(union: false)]
  struct ANativeWindowBuffer
    width  : Int32
    height : Int32
    stride : Int32
    format : Int32
    bits   : Void*
    reserved : UInt32[6]
  end

  fun is_destroy_requested(app : Void*) : Int32
  fun get_poll_source_process_func(source : Void*) : Void*
  fun call_process_func(source : Void*, app : Void*)
  fun lock_window = ANativeWindow_lock(window : Void*, out_buffer : ANativeWindowBuffer*, dirty_bounds : Void*) : Int32
  fun unlock_window = ANativeWindow_unlockAndPost(window : Void*) : Int32
  fun lock_window_and_get_pixels = lock_window_and_get_pixels(window : Void*, out_width : Int32*, out_height : Int32*) : Void*
  fun get_app_window = get_app_window(app : Void*) : Void*
end

fun android_main(app_ptr : Void*)
  # Cast the Void* to an AndroidApp*
  app = app_ptr.as(AndroidApp*)

  window_ready = false

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

        if cmd >= 0
          LibAndroidGlue.android_app_pre_exec_cmd(app_ptr, cmd)

          android_log("processing cmd (after pre_exec): #{cmd} enum: #{LibAndroidGlue::AppCmd.new(cmd)}")

          # Handle the commands
          case LibAndroidGlue::AppCmd.new(cmd)
          when .init_window?
            android_log("Window is initialized!")
            window_ready = true # Set the flag
          when .term_window?
            android_log("Window is being destroyed.")
            window_ready = false # Clear the flag
          end

          LibAndroidGlue.android_app_post_exec_cmd(app_ptr, cmd)
        end
      end
    end

    # main game loop
    # Inside your loop
    window_ptr = LibAndroidHelper.get_app_window(app_ptr)

    # 1. ONLY draw if window_ready is true AND window_ptr is NOT null
    if window_ready && window_ptr != nil
      # android_log("window ready and ptr not nil")

      w, h = 0, 0

      # 1. Prepare a buffer struct
      buffer = LibAndroidHelper::ANativeWindowBuffer.new

      # 2. Lock the window
      if LibAndroidHelper.lock_window(window_ptr, pointerof(buffer), nil) == 0
        # android_log("window locked, and got buffer, set pixels")

        # android_log(">>> Buffer Info: W=#{buffer.width}, H=#{buffer.height}, Stride=#{buffer.stride}, Format=#{buffer.format}")

        # If the width or height are massive, or stride is 0 or a negative number,
        # your struct definition is misaligned.
        if buffer.width <= 0 || buffer.stride <= 0 || buffer.width > 4096
          # android_log("!!! ERROR: Invalid buffer dimensions. Struct definition is likely wrong.")
          # return
        end

        pixel_base = buffer.bits.as(UInt8*)
        # Calculate the total size of the buffer in bytes
        buffer_size_bytes = buffer.stride * buffer.height * 4

        (0...(buffer.height / 2)).each do |y|
          row_offset = y * buffer.stride * 4

          # Bounds check: ensure the start of the row is within the buffer
          if (pixel_base + row_offset).address >= (buffer.bits.as(UInt8*) + buffer_size_bytes).address
            break
          end

          row_ptr = (pixel_base + row_offset).as(UInt32*)

          (0...buffer.width).each do |x|
            # Bounds check: ensure the specific pixel is within the buffer
            if (pixel_base + row_offset + (x * 4)).address < (buffer.bits.as(UInt8*) + buffer_size_bytes).address
              row_ptr[x] = 0xFFFF0000_u32
            end
          end
        end

        # android_log("unlock window")

        # 5. Unlock to display the changes
        LibAndroidHelper.unlock_window(window_ptr)
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
