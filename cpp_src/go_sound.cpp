#include "go_sound.h"
#include "Util.h"
#include <cstdio>

GoSDL::Sound::~Sound ()
{
    unload();
}

void GoSDL::Sound::setSample (std::string path)
{
    std::string mPath = getBasePath() + path;
    mSample = Mix_LoadWAV(mPath.c_str());

    if(!mSample)
    {
        printf("Mix_LoadWAV: %s\n", Mix_GetError());
    }
}

void GoSDL::Sound::unload ()
{
    if (mSample != nullptr) {
        Mix_FreeChunk(mSample);
        mSample = nullptr;
    }
}

void GoSDL::Sound::play (float vol)
{
    if (mSample == nullptr)
    {
        return;
    }

    Mix_VolumeChunk(mSample, 128 * vol);
    Mix_PlayChannel(-1, mSample, 0);
}