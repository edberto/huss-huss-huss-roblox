# Trailer

Edits the Studio captures in `.trailer/` (git-ignored, with the fonts in `.trailer/fonts/`) into:

- `make.py` - first cut (letterboxed, 37 s); also the shared sample loader.
- `make2.py` - 15 s vertical (1080x1920) for TikTok / Shorts / Reels.
- `make3.py` - 30 s 16:9 store trailer; `--roblox` drops the call to action on the end card
  (Roblox's video rules forbid promotion; upload that one in Creator Hub > Places > Videos).

Every capture starts with a one-frame magenta sync flash and the hits land on a 0.5 s grid after
it (`findflash.py` finds the flash). Finished videos live in `marketing/` (git-ignored).
Score is our own samples from `assets/audio` only.
