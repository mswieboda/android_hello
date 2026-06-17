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

  # Initialize SDL3
  if !SDL3.init(SDL3::InitFlags::Video | SDL3::InitFlags::Audio)
    android_log("SDL3 init Failed")
    return 1
  end
  android_log("SDL3 init successfully")

  if !SDL3::Mixer.init
    android_log("SDL3 Mixer init Failed")
    return 1
  end
  android_log("SDL3 Mixer init successfully")

  # Pump events for a few cycles to let Android initialize the surface
  # and send window size events over to SDL's native backend.
  5.times do
    SDL3.pump_events
    SDL3.delay(16)
  end
  android_log("Initial event pumping completed")

  # Create window and renderer
  # Android completely ignores the width/height parameters and forces fullscreen
  window = SDL3::Window.new("hello sdl3.cr", 0, 0, SDL3::Window::Flags::Fullscreen)
  android_log("Window created successfully")

  renderer = SDL3::Renderer.new(window)
  renderer.vsync = 1
  android_log("Renderer created successfully")

  # fetch actual render size dynamically
  screen_w, screen_h = renderer.output_size
  android_log("Display size: #{screen_w}x#{screen_h}")

  # set up square
  # Define the square's dimensions
  rect_width = 300.0_f32
  rect_height = 300.0_f32

  # Android window size from your logs is 1080x2424
  # Calculate center positioning dynamically
  rect_x = (screen_w.to_f32 - rect_width) / 2.0_f32
  rect_y = (screen_h.to_f32 - rect_height) / 2.0_f32

  # Create the SDL3 Floating-point Rectangle structure
  square = SDL3::FRect.new(x: rect_x, y: rect_y, w: rect_width, h: rect_height)

  # set up image
  # texture = LibSDL3Image.load_texture(renderer, "palm-tree.png".to_unsafe)
  texture = SDL3::Image.load_texture(renderer, "palm-tree.png")
  android_log("Texture loaded successfully!")

  # 2. Fetch texture size (SDL3 uses Float32 here)
  img_w, img_h = texture.size
  android_log("Image size: #{img_w.to_i}x#{img_h.to_i}")

  # 3. Center the image (Cast the screen integers to floats for the math)
  rect_x = (screen_w.to_f32 - img_w) / 2.0_f32
  rect_y = (screen_h.to_f32 - img_h) / 2.0_f32
  dest_rect = SDL3::FRect.new(x: rect_x, y: rect_y, w: img_w, h: img_h)

  # set up mixer and track
  mixer = SDL3::Mixer::Device.create

  # 3. Create a track lane to play sounds on
  track = SDL3::Mixer::Track.create(mixer)

  # 4. Load your ding clip directly using the unified audio loader
  audio = SDL3::Mixer::Audio.load(mixer, "ding.wav", true)

  # 5. Wire the audio data source onto your active playback track lane
  track.audio = audio

  # use counter to trigger test audio play
  audio_counter = 0

  # Standard game loop
  running = true
  event = uninitialized LibSDL3::Event

  while running
    while SDL3.poll_event(pointerof(event))
      if event.type == LibSDL3::SDL_EVENT_QUIT
        android_log("Received Quit Event!")
        running = false
      end
    end

    audio_counter += 1
    if audio_counter % 100 == 0
      android_log("PLAY TRACK!")
      track.play(0)
    end

    # clear
    renderer.draw_color = {0_u8, 0_u8, 0_u8, 255_u8} # Black
    renderer.clear

    # draw
    renderer.draw_color = {200_u8, 200_u8, 200_u8, 255_u8} # Light Grey
    renderer.fill_rect(square)

    # image
    renderer.render_texture(texture: texture, dest_rect: dest_rect)

    # present
    renderer.present

    # delay, to limit FPS (to about 60 FPS)
    SDL3.delay(16)
  end

  # Cleanup
  android_log("Shutting down SDL3...")

  audio.destroy
  track.destroy
  mixer.destroy

  SDL3::Mixer.quit

  renderer.destroy
  window.destroy

  SDL3.quit

  return 0
end
