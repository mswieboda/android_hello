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
  # if !SDL3.init(SDL3::InitFlags::Video | SDL3::InitFlags::Audio)
  if !LibSDL3.init(LibSDL3::SDL_INIT_VIDEO | LibSDL3::SDL_INIT_AUDIO)
    android_log("SDL3 init Failed")
    # Add get_error to find out exactly why it failed!
    error_msg = String.new(LibSDL3.get_error)
    android_log("SDL3 init Failed: #{error_msg}")
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

  # set up square
  # Define the square's dimensions
  rect_width = 300.0_f32
  rect_height = 300.0_f32

  # Android window size from your logs is 1080x2424
  # Calculate center positioning dynamically
  rect_x = (1080.0_f32 - rect_width) / 2.0_f32
  rect_y = (2424.0_f32 - rect_height) / 2.0_f32

  # Create the SDL3 Floating-point Rectangle structure
  square = LibSDL3::FRect.new(x: rect_x, y: rect_y, w: rect_width, h: rect_height)

  # set up image
  texture = LibSDL3Image.load_texture(renderer, "palm-tree.png".to_unsafe)
  if texture.nil?
    error_msg = String.new(LibSDL3.get_error)
    android_log("Failed to load texture: #{error_msg}")
    return 1
  end
  android_log("Texture loaded successfully!")

  # fetch actual render size dynamically
  screen_w = 0
  screen_h = 0
  LibSDL3.get_render_output_size(renderer, pointerof(screen_w), pointerof(screen_h))
  android_log("Display size: #{screen_w}x#{screen_h}")

  # 2. Fetch texture size (SDL3 uses Float32 here)
  img_w = 0_f32
  img_h = 0_f32
  LibSDL3.get_texture_size(texture, pointerof(img_w), pointerof(img_h))
  android_log("Image size: #{img_w.to_i}x#{img_h.to_i}")

  # 3. Center the image (Cast the screen integers to floats for the math)
  rect_x = (screen_w.to_f32 - img_w) / 2.0_f32
  rect_y = (screen_h.to_f32 - img_h) / 2.0_f32
  dest_rect = LibSDL3::FRect.new(x: rect_x, y: rect_y, w: img_w, h: img_h)

  # set up mixer and track
  # # Create a mixer using high-level wrapper
  # mixer = SDL3::Mixer::Device.create(LibSDL3::AUDIO_DEVICE_DEFAULT_PLAYBACK)

  # # Load the sound using high-level wrapper
  # # audio = SDL3::Mixer::Audio.load(mixer, "ding.wav", false)
  # audio = SDL3::Mixer::Audio.load_wav(mixer, "ding.wav", false)

  # # Create a track using high-level wrapper
  # track = SDL3::Mixer::Track.create(mixer)
  # track.audio = audio
  # 0xFFFFFFFF_u32 matches SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK
  mixer = LibSDL3Mixer.create_mixer_device(0xFFFFFFFF_u32, Pointer(LibSDL3::AudioSpec).null)

  # 3. Create a track lane to play sounds on
  track = LibSDL3Mixer.create_track(mixer)

  # 4. Load your ding clip directly using the unified audio loader
  audio = LibSDL3Mixer.load_audio(mixer, "ding.wav".to_unsafe, true)

  # 5. Wire the audio data source onto your active playback track lane
  LibSDL3Mixer.set_track_audio(track, audio)

  audio_counter = 0

  # Standard game loop
  running = true
  event = uninitialized LibSDL3::Event

  while running
    while LibSDL3.poll_event(pointerof(event))
      if event.type == LibSDL3::SDL_EVENT_QUIT
        android_log("Received Quit Event!")
        running = false
      end
    end

    audio_counter += 1
    if audio_counter % 100 == 0
      android_log("PLAY TRACK!!! >>>>>>>>>")
      # track.play(0)
      LibSDL3Mixer.play_track(track, 0)
    end

    # clear
    LibSDL3.set_render_draw_color(renderer, 255_u8, 0_u8, 0_u8, 255_u8)
    LibSDL3.render_clear(renderer)

    # draw
    # LibSDL3.set_render_draw_color(renderer, 200, 200, 200, 255) # Light Grey
    # LibSDL3.render_fill_rect(renderer, pointerof(square))

    # image
    # Render the texture onto the screen back-buffer
    LibSDL3.render_texture(renderer, texture, Pointer(LibSDL3::FRect).null, pointerof(dest_rect))

    # present
    LibSDL3.render_present(renderer)

    # delay, to limit FPS (to about 60 FPS)
    LibSDL3.delay(16)
  end

  # Cleanup
  android_log("Shutting down SDL3...")

  # audio.destroy
  LibSDL3Mixer.destroy_audio(audio)
  # track.destroy
  LibSDL3Mixer.destroy_track(track)
  # mixer.destroy
  LibSDL3Mixer.destroy_mixer(mixer)

  SDL3::Mixer.quit

  LibSDL3.destroy_renderer(renderer)
  LibSDL3.destroy_window(window)
  SDL3.quit

  return 0
end
