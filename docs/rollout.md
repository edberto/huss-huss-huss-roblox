# Rollout note

Manual place changes that a code publish doesn't carry. Newest first.

## 2026-11-26: Shop thumbnails

- Uploaded 23 shop thumbnails (assets/shop/, from `scripts/shop_thumbs.py`) as images under
  user 7089502211; ids are in `THUMBS` in src/client/ShopClient.luau. Nothing to do per place.
- [ ] Creator Hub: set the Party Animal pass (2100270141) icon to assets/icons/party_animal.png
  (the shop falls back to the drawn thumb until then).

## 2026-11-26: Front practice cameras (PLAYTEST)

- Moved PracticeCamera_Gym / PracticeCamera_Burgers in all 12 PLAYTEST homes to face the
  player from the garage door / outside the kitchen window (same as `scripts/build_scene.luau`).
  Production gets them when the scene script is run there.

## 2026-11-26: Party Tickets

- Uploaded via Studio MCP: ticket icon 96730617685238 and coin icon 117706289482395
  (assets/ui/). Party Animal pass icon is assets/icons/party_animal.png.
- [x] Party Animal game pass 2100270141 created in Creator Hub (149 Robux) and set in
  `Products.partyAnimalPassId`. (Open Cloud refused to create it from the PLAYTEST Studio.)

## 2026-11-25: Practice rooms (PLAYTEST)

- Rebuilt workspace.Homes in PLAYTEST from `scripts/build_scene.luau` (homes section only): each
  home now has an open garage gym and a kitchen behind a picture window, with
  PracticeSpot_Gym / PracticeSpot_Burgers and PracticeCamera_Gym / PracticeCamera_Burgers.
  Basketball keeps PracticeSpot / PracticeCamera on the driveway.
- Production still has the old solid homes: run `scripts/build_scene.luau` there before the
  next Production publish (the code falls back to the driveway if the room spots are missing).

## 2026-11-25: Production experience created
- Studio File > New, ran scripts/build_scene.luau, synced default.project.json with Rojo (port 34875).
- Published as a new experience owned by Flamingo Skies Pier (group 962391373):
  universe 10778958069, place 71858386860011. Private (only collaborators). Team Create on.
- Experience Settings > Security: Enable Studio Access to API Services on.
- Creator Hub: VIP pass 2100887538 (199, on sale); developer products 500 Huss 3736028510 (25),
  1,750 Huss 3736028729 (75), 5,000 Huss 3736028812 (199), Second Wind 3736028871 (15),
  Throw a Party 3736028927 (99). Managed pricing off on all (in-game prices are fixed).
- Creator Hub: developer product Huss Boost 3736030396 (29, managed pricing off).

## Before the first Production publish (checklist)

- [x] Game Settings: max players 12 (Production place serverSize 12, checked 2026-11-26).
- [x] Game Settings > Security: enable Studio Access to API Services (PlayTest). Saves tested 2026-11-26: bought a dance, rejoined, Huss and owned items persisted.
- [ ] Create the Roblox group; set `GROUP_ID` in `src/server/services/RewardService.luau`.
- [ ] Create the VIP game pass and 5 developer products (HP 500 / 1,750 / 5,000, Second Wind,
      Throw a Party); fill the ids in `src/shared/Products.luau`.
- [ ] Production place: run `scripts/build_scene.luau`, set max players, then publish from Rojo
      with `default.project.json`.
- [ ] Phone test with real players (touch layout was checked by maths only).
- [x] Own "huss" recordings (6 takes, assets/audio, IDs in StationFx).
- [x] Own "ahh almost almost" recording (assets/audio, ID in StationFx).
- [ ] Upload `assets/thumbnail.png` as the experience thumbnail (Creator Hub > Places > Thumbnails).
- [ ] Tag the published version (`v0.1.0`).

## 2026-11-24 - [PLAYTEST] place (121340921046411)

- Rebuilt the town with `scripts/build_scene.luau` for 12 players: workspace.Homes (Home1-12, six
  per side of the street) and the party house at the west end of the street (with side windows).
  Replaces the single workspace.Home. SpawnLocation moved to the street; players are placed on
  their home's PracticeSpot by code.
- Turned the party house 180 degrees so its front, guests and lawn face down the street
  (scene script fixed to match).
- To do in Game Settings: max players 12.

- Built the night town with `scripts/build_scene.luau` (Home with hoop, ball, practice camera;
  party house next door; street, lamps, moon; night Lighting). Baseplate recoloured, grid texture
  removed, SpawnLocation moved to the practice spot and hidden.
- Production: ran the same script there 2026-11-26 (12 homes, front cameras, lighting).
- 2026-11-25 Production social links: Discord https://discord.gg/rCDG7sVwAa ("Flamingo Skies Pier Discord"), Roblox Community 962391373 ("Join Flamingo Skies Pier (+50% Huss)"). Group bonus raised to +50% (Rewards.groupBonus 0.5)..
- 2026-11-25 Huss Boost icon added (assets/icons/huss_boost.png). Uploaded 2026-11-25 via Studio MCP (Open Cloud): VIP pass + 6 product icons, thumbnail as homepage thumbnail (asset 90884851085639, approved). Spare image asset 135196325607800 also uploaded, unused. Experience icon still missing.
- 2026-11-25 Production published as version 7: Huss Boost + group bonus +50% live.
- 2026-11-25 Experience icon set (image 135129487613355, Open Use) and detail-page thumbnail set (image 99786376501858, Open Use) via Assets API updateMask=icon/previews. Earlier non-Open-Use uploads 119525705898812 and 135196325607800 are unused.
- 2026-11-25 Uploaded via Studio MCP: beat kick audio 128535338677323 (assets/audio/beat_kick.wav, our own synth; was in moderation review at upload) and Settings icon 111747124734544 (assets/ui/settings.png). Night Huss is now practice points / 10 (Progress.hussPerPoint).
- 2026-11-26 Production: granted universe 10778958069 Use permission on 48 of our uploaded assets (sounds, shop thumbnails, icons) via asset-permissions API; beat kick, settings icon and new thumbnails were blocked before. Experience is now Public (needed for video upload).
