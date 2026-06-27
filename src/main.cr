require "game_sdl"

lib LibAndroidLog
  # Bind directly to the NDK log library
  fun write = __android_log_write(prio : Int32, tag : UInt8*, text : UInt8*) : Int32
end

def android_log(message : String)
  # Write directly to logcat using basic pointers, completely skipping
  # standard string allocations until we initialize the GC heap later.
  LibAndroidLog.write(4, "CrystalGame".to_unsafe, ">>> #{message}".to_unsafe)
end

def alog(msg : String)
  LibAndroidLog.write(4, "AndroidGameRun".to_unsafe, ">>> #{msg}".to_unsafe)
end

module AndroidHello
  class Game < GSDL::Game
    def initialize
      super(
        title: "hello GSDL",
        width: 0,
        height: 0,

        # TODO: might not be android supported, and ignored
        # i don't notice any difference here
        # high_pixel_density: true,

        # TODO: this crashes without errors, so need to debug it:
        # logical_width: 360,
        # logical_height: 800,
      )
    end

    def self.org_name
      "mswieboda"
    end

    def self.title_name
      "hello_gsdl"
    end

    def init
      self.target_fps = 60

      push(StartScene.new)
    end

    def load_default_font
      "fonts/Electrolize-Regular.ttf"
    end

    def load_textures
      [{"palm_tree", "gfx/palm-tree.png"}]
    end
  end

  class StartScene < GSDL::Scene
    @text : GSDL::Text
    @sprite : GSDL::Sprite
    # @texture : GSDL::Texture
    @frames = 0

    def initialize
      super(:start)

      @text = GSDL::Text.new(
        text: "Testing Sprite and Text",
        font_size: 64,
        origin: {0.5_f32, 0.5_f32},
        color: GSDL::Color::Lime
      )
      @text.x = Game.width / 2_f32
      @text.y = @text.height + 256

      @sprite = GSDL::Sprite.new(
        key: :palm_tree,
        x: Game.width / 2_f32,
        y: Game.height / 2_f32,
        origin: {0.5_f32, 0.5_f32}
      )
    end

    def draw_camera_view(draw : GSDL::Draw)
      @text.draw(draw)
      @sprite.draw(draw)
    end
  end
end

# Ensure the Crystal module is available if not already required
require "crystal/main"

fun crystal_game_main : Int32
  android_log("Entering crystal_game_main...")
  android_log("Invoking Crystal runtime setup...")

  # Crystal.main with a block initializes the GC, runtime structures,
  # and environment hooks, then executes the block code cleanly.
  # Crucially, it leaves error handling and system state un-collapsed.
  Crystal.main do
    android_log("Crystal runtime setup completed successfully!")

    # Create dummy arguments to pass down to the user code initialization
    argc = 0
    argv = Pointer(Pointer(UInt8)).null

    # This kicks off the evaluation of all your required files,
    # building the Dragonbox float cache and setting up top-level code.
    android_log("Crystal.main_user_code called...")
    Crystal.main_user_code(argc, argv)
    android_log("Crystal.main_user_code completed successfully!")

    # 2. Block this thread right here inside the safety bubble!
    # This keeps crystal_game_main from exiting prematurely.
    android_log("Starting explicit game loop execution...")
    AndroidHello::Game.new.run
    android_log("Game loop execution finished natively.")
  end

  android_log("Handing control back to SDL cleanly.")

  0
end

# =============================================================================
# 2. TOP-LEVEL USER CODE
# =============================================================================
# Leave this area purely for static setups, registrations, or engine configurations.
# Do NOT call `.run` or return values down here.
android_log("Top-level program structures and classes loaded.")
