# Rollout note

Manual place changes that a code publish doesn't carry. Newest first.

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
