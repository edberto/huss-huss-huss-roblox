# Rollout note

Manual place changes that a code publish doesn't carry. Newest first.

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

- [ ] Game Settings: max players 12 (both places).
- [ ] Game Settings > Security: enable Studio Access to API Services (PlayTest) so saves can be tested.
- [ ] Create the Roblox group; set `GROUP_ID` in `src/server/services/RewardService.luau`.
- [ ] Create the VIP game pass and 5 developer products (HP 500 / 1,750 / 5,000, Second Wind,
      Throw a Party); fill the ids in `src/shared/Products.luau`.
- [ ] Production place: run `scripts/build_scene.luau`, set max players, then publish from Rojo
      with `default.project.json`.
- [ ] Phone test with real players (touch layout was checked by maths only).
- [ ] Replace the placeholder sounds with our own recordings (huss, "almost almost").
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
- Not yet in Production: run the same script there before the first Production publish.
