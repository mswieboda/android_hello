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
    android_log("SDL3 init Failed")
    # Add get_error to find out exactly why it failed!
    error_msg = String.new(LibSDL3.get_error)
    android_log("SDL3 init Failed: #{error_msg}")
    return 1
  end
  android_log("SDL3 init successfully")

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

  # Define the square's dimensions
  rect_width = 300.0_f32
  rect_height = 300.0_f32

  # Android window size from your logs is 1080x2424
  # Calculate center positioning dynamically
  rect_x = (1080.0_f32 - rect_width) / 2.0_f32
  rect_y = (2424.0_f32 - rect_height) / 2.0_f32

  # Create the SDL3 Floating-point Rectangle structure
  square = LibSDL3::FRect.new(x: rect_x, y: rect_y, w: rect_width, h: rect_height)

  while running
    while LibSDL3.poll_event(pointerof(event))
      if event.type == LibSDL3::SDL_EVENT_QUIT
        android_log("Received Quit Event!")
        running = false
      end
    end

    # clear
    LibSDL3.set_render_draw_color(renderer, 255_u8, 0_u8, 0_u8, 255_u8)
    LibSDL3.render_clear(renderer)

    # draw
    LibSDL3.set_render_draw_color(renderer, 200, 200, 200, 255) # Light Grey
    LibSDL3.render_fill_rect(renderer, pointerof(square))

    # present
    LibSDL3.render_present(renderer)

    # delay, to limit FPS (to about 60 FPS)
    LibSDL3.delay(16)
  end

  # Cleanup
  android_log("Shutting down SDL3...")
  LibSDL3.destroy_renderer(renderer)
  LibSDL3.destroy_window(window)
  SDL3.quit

  return 0
end
