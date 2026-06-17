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

fun crystal_game_main : Int32
  android_log("Crystal has taken control inside the game loop!")

  # Initialize SDL3 (Video is already attached by the SDL3 Android subsystem)
  if !LibSDL3.init(LibSDL3::SDL_INIT_VIDEO)
    android_log("SDL_Init Failed")
    # Add get_error to find out exactly why it failed!
    error_msg = String.new(LibSDL3.get_error)
    android_log(">>> SDL_Init Failed: #{error_msg}")
    return 1
  end
  android_log("SDL_Init successfully returned true!")

  # Pump events for a few cycles to let Android initialize the surface
  # and send window size events over to SDL's native backend.
  5.times do
    LibSDL3.pump_events
    LibSDL3.delay(16)
  end
  android_log("Initial event pumping completed.")

  # Create your window and renderer
  # Android completely ignores the width/height parameters and forces fullscreen
  window = LibSDL3.create_window("GSDL Game", 0, 0, LibSDL3::SDL_WINDOW_FULLSCREEN)
  if window.nil?
    android_log("Failed to create window")
    return 1
  end
  android_log("Window created successfully at memory pointer location.")

  renderer = LibSDL3.create_renderer(window, nil)
  if renderer.nil?
    android_log("Failed to create renderer")
    return 1
  end
  android_log("Renderer created successfully.")

  # Standard game loop
  running = true
  event = uninitialized LibSDL3::Event
  frame_count = 0

  while running
    while LibSDL3.poll_event(pointerof(event))
      if event.type == LibSDL3::SDL_EVENT_QUIT
        android_log("Received Quit Event!")
        running = false
      end
    end

    # Track if drawing commands actually succeed
    color_ok = LibSDL3.set_render_draw_color(renderer, 255_u8, 0_u8, 0_u8, 255_u8)
    clear_ok = LibSDL3.render_clear(renderer)
    present_ok = LibSDL3.render_present(renderer)

    # Log only the first 3 frames to avoid absolutely flooding your logcat
    if frame_count < 3
      android_log("Frame ##{frame_count}: Color OK: #{color_ok}, Clear OK: #{clear_ok}, Present OK: #{present_ok}")
      if !color_ok || !clear_ok || !present_ok
        android_log("Render Error: #{String.new(LibSDL3.get_error)}")
      end
      frame_count += 1
    end

    LibSDL3.delay(16)
  end

  # Cleanup
  android_log("Shutting down SDL3...")
  LibSDL3.destroy_renderer(renderer)
  LibSDL3.destroy_window(window)
  LibSDL3.quit

  return 0
end
