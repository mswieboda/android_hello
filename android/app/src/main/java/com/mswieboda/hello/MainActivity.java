package com.mswieboda.hello;

import org.libsdl.app.SDLActivity;

public class MainActivity extends SDLActivity {
    @Override
    protected String[] getLibraries() {
        return new String[] {
            "SDL3",
            "SDL3_image",
            "SDL3_mixer",
            "SDL3_ttf",
            "main"
        };
    }
}
