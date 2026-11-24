# Huss Huss Huss: While They Party

Roblox game: everyone in town goes out partying except you. Practice on the beat, ignore the
party, last until dawn.

Design doc: https://claude.ai/artifact/6JnwgArAEMXayH4CdpsFKi

## Setup

```sh
rokit install
wally install
rojo serve                       # Production place
rojo serve playtest.project.json # [PLAYTEST] place
```

Checks before publishing: `stylua src tests`, `selene src`, `rojo build -o build.rbxl`, and the
Jest suite (`jest-roblox`, same Open Cloud setup as mahjong-mayhem).

## Layout

- `src/shared` - code both sides use (`BeatClock` judges taps on the beat)
- `src/server` - round, stations, focus, party, data services
- `src/client` - rhythm track, input, UI
- `tests` - Jest specs, only for logic where a bug costs players progress
