# V.Smile demo (the one with a dragon)

It was done for the RGPlay 2024 at Meaux, France.

!(RGPlay demo in action)[readme/demo.gif]

Features:
- Animated sprite (the dragon)
- Parallax scrolling on both layers (the stars)
- Music playback (the annoying sound)
- Input (not working on hardware, but OK in emulators)

This is also the begining of the work on a small engine, with current features being:
- Music and SFXs extracted from MP3 audio files
- Background imported from "Tiled" map at build time: work in Tiled, build the game without export/import steps
- Init and Tick functions for the game, hardware stuff and main loop done for you

Have fun reading the source: the fun stuff starts in `src/logic/rom.asm`
