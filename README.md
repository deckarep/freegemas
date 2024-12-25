<p align="center">
    <img src="https://raw.githubusercontent.com/deckarep/freegemas/static/images/header_logo.png"><br>
    <img src="https://raw.githubusercontent.com/deckarep/freegemas/static/images/header_gems.png"><br>
</p>

__Freegemas__ is a GPL2.0 open source version of the well known Bejeweled, for MacOS and ~GNU/Linux, Windows, Playstation Vita~. It's written in [Zig 0.13.0](https://ziglang.org) using [SDL2](https://www.libsdl.org/). This version is a Zig-based port of the [original C++ version by Jose Tomas Tocino](https://github.com/JoseTomasTocino/freegemas). Since the original license is an
open source copyleft license this repo is required to use the same exact license.

<p align="center">
    <img src="https://github.com/deckarep/freegemas/blob/zig-version/static/images/screenshot_1.png">
</p>    
        
## Installation on OS X

First, head over to [ziglang.org](https://ziglang.org) and download *Zig 0.13.0* or newer.

This assumes that you are already using [Homebrew](https://brew.sh/). You will need a few libraries to compile Freegemas:

    brew install sdl2 sdl2_mixer sdl2_ttf sdl2_image

Now run the following commands to setup your environment to use Homebrew as a backup location for libraries.

After that, clone the repo:

    git clone https://github.com/deckarep/freegemas.git
    
Do an out-of-source compilation and run the program:

    cd freegemas
    zig build run
    ./freegemas

## Music licensing

The music in the game is [Easy Lemon by Kevin MacLeod](https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1200076)
Licensed under [Creative Commons: By Attribution 3.0](https://creativecommons.org/licenses/by/3.0/)
