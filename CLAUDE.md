# Working rules

Goal: launch by 5 Dec 2026 as a solo project. Speed first; anything players can't see waits.

- Commit straight to `main`; tag each published version (`v0.1.0`, ...). No issue/PR per change.
- One session does engineering, assets and audio. No lead handoffs.
- Tests only for rhythm scoring and saved data. Run stylua, selene and a rojo build before pushing.
- Test in the [PLAYTEST] experience before publishing to Production.
- Log manual place changes (anything a code publish doesn't carry) in `docs/rollout.md` the same day.
- Show a quick mock before building UI or the thumbnail.
- Record our own voice lines and sounds; never upload clips from the original meme videos.

## Reuse from mahjong-mayhem (D:/rblx-creations/mahjong-mayhem)

Port when the feature is needed, trimmed to what this game uses:

- `src/server/services/Economy.luau` - currency grants with transaction ids
- `src/server/services/Retention.luau` - daily check-in, playtime, codes, group reward rules
- `src/server/services/RedeemCodes.luau`, `src/server/runtime/Leaderstats.luau`
- `ProfileService.luau` is game-specific (1,800 lines); write a lean one instead of porting it.
