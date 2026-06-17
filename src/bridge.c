#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include <android/log.h>

// Tell Android's logcat who is talking
#define LOG_TAG "GSDL_Bridge"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

// Declare the game loop function that you will implement in Crystal
extern int crystal_game_main(void);

/*
 * This is the signature SDL3 expects on Android.
 * Including <SDL3/SDL_main.h> ensures that when Java starts the application,
 * it safely routes through SDL3's initialization layer and lands right here.
 */
int main(int argc, char *argv[]) {
    LOGI("SDL3 Java layer handshake successful. Handoff to Crystal...");

    // Call your game loop written in Crystal
    int result = crystal_game_main();

    LOGI("Crystal game loop finished with exit code: %d", result);
    return result;
}
