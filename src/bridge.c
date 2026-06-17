#include <android_native_app_glue.h>

int is_destroy_requested(struct android_app* app) {
    return app->destroyRequested;
}

void* get_app_window(struct android_app* app) {
    return app->window;
}

void* get_poll_source_process_func(struct android_poll_source* source) {
    return (void*)source->process;
}

void call_process_func(struct android_poll_source* source, struct android_app* app) {
    source->process(app, source);
}

void* lock_window_and_get_pixels(ANativeWindow* window, int32_t* out_width, int32_t* out_height) {
    ANativeWindow_Buffer buffer;
    if (ANativeWindow_lock(window, &buffer, NULL) == 0) {
        *out_width = buffer.width;
        *out_height = buffer.height;
        return buffer.bits;
    }
    return NULL;
}

void unlock_window(ANativeWindow* window) {
    ANativeWindow_unlockAndPost(window);
}
