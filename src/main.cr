require "sdl3"

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
  android_log("android_main...")

  # Cast the Void* to an AndroidApp*
  app = app_ptr.as(AndroidApp*)

  window_ready = false

  # Variables to hold the output from the poll function
  out_fd = 0
  out_events = 0
  source_data = pointerof(out_fd) # Just placeholders for the poll

  # heartbeat
  counter = 0

  android_log "Initializing SDL3..."
  # try without sdl3_mixer, sdl3_image, sdl3_ttf
  # put back in scancode, keycode
  # if SDL3.init(LibSDL3::SDL_INIT_VIDEO) != 0
  #   android_log("Failed to initialize SDL3: #{SDL3.get_error}")
  #   return
  # end
  result = LibSDL3.init(LibSDL3::SDL_INIT_VIDEO)
  if result != 0
    android_log("SDL_Init returned: #{result}")
    # Manually call LibSDL.get_error if you need to,
    # but be careful with String allocations!
    # android_log("Failed to initialize SDL3: #{SDL3.get_error}")
  end
  android_log "SDL3 Initialized."

  window = nil.as(LibSDL3::Window?)
  renderer = nil.as(LibSDL3::Renderer?)

  android_log("android_main... Starting event loop...")

  # 2. Main Loop
  loop do
    # A. Process Android Events (Keep the app alive)
    # This prevents the "App Not Responding" (ANR) error
    event = uninitialized LibSDL3::Event
    while SDL3.poll_event(pointerof(event))
      case event.type
      when LibSDL3::SDL_EVENT_WINDOW_SHOWN
        if window.nil?
          android_log "Window shown event received, creating SDL window..."
          window = LibSDL3.create_window("Hello SDL3".to_unsafe, 480, 640, 0)
          renderer = LibSDL3.create_renderer(window.not_nil!, Pointer(UInt8).null)
        end
      when LibSDL3::SDL_EVENT_QUIT, LibSDL3::SDL_EVENT_WINDOW_CLOSE_REQUESTED
        puts "Crystal: Quit event received."
        running = false
      end
    end

    # B. Render your frame
    # (Your existing renderer code here)
    LibSDL3.set_render_draw_color(renderer.not_nil!, 255_u8, 0_u8, 0_u8, 255_u8)
    # renderer.draw_color={255_u8, 0_u8, 0_u8, 255_u8}
    LibSDL3.render_clear(renderer.not_nil!)
    # renderer.clear
    LibSDL3.render_present(renderer.not_nil!)
    # renderer.present

    # C. Check for exit
    break if LibAndroidHelper.is_destroy_requested(app_ptr) != 0
  end

  LibSDL3.destroy_gpu_render_state(renderer.not_nil!)
  LibSDL3.destroy_window(window.not_nil!)
  SDL3.quit
end
