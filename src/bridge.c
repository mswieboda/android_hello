#include <android_native_app_glue.h>

// This function takes the app pointer, casts it to the correct type, 
// and returns the value of the flag.
int is_destroy_requested(struct android_app* app) {
    return app->destroyRequested;
}

// You'll likely need this one soon too
void* get_app_window(struct android_app* app) {
    return app->window;
}

void* get_poll_source_process_func(struct android_poll_source* source) {
    return (void*)source->process;
}

void call_process_func(struct android_poll_source* source, struct android_app* app) {
    source->process(app, source);
}
