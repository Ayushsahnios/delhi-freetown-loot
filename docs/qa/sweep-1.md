# QA Sweep 1 — full-loop functional audit (issue #168)

Date: 2026-10-28 · Lane D · headless Godot 4.7.2 against `main.tscn`
via a scripted driver (title → start → move → teleports → vehicle →
metro ride → police heat → food → pause → death → busted → save/load →
corrupt save). Verdict lines print `SWEEP168 PASS/FAIL` per check.

## Headline finding — metro shuttle frozen mid-viaduct (FIXED)

**Symptom:** after its first departure the shuttle never reached the far
station; boarding queues ("TRAIN EN ROUTE") waited forever and any rider
was stuck between stations for good.

**Root cause:** `metro.gd` recomputed the destination every frame as
"farthest station" — `target = station1.z if at0 < at1 else station0.z`.
At the exact midpoint (z = 51, dead centre between z=-40 and z=142) the
comparison flips each frame, so the train oscillated ±0.15 m around the
midpoint at cruise speed forever. Probe trace (pre-fix):

```
t=9.8  state=run speed=24.00 z=28.99   ← outbound, healthy
t=11.8 state=run speed=24.00 z=51.16   ← hits midpoint
t=13.8 state=run speed=24.00 z=51.16   ← frozen (target flips per frame)
t=25.8 state=run speed=24.00 z=51.29   ← still there 14 s later
```

**Fix:** pin the destination once, at departure (`_target_z` set in the
dwell→run transition); the run leg keeps it until the arrival check
fires. Post-fix sweep: full dwell→board→ride→alight cycle passes.

## Full check list (post-fix run)

| Stage | Checks | Result |
|---|---|---|
| Title | select layer builds; 3 portrait viewports with own worlds (issue #152 regression); CONTINUE matches save presence | PASS |
| Start | player spawns, finite pos, solid ground under spawn | PASS |
| Move | 1.5 s walk displacement 9.5 m; no NaN / fall-through | PASS |
| Teleport settle | 10 spots (Chandni Chowk + landmarks): no fall-through (worst y-drift 2.06 m) | PASS |
| Vehicle | board parked auto (player hidden), 26 m/s top speed, exit restores player, sane exit pos | PASS |
| Metro | dwell wait → board (player hidden, controls off) → ride to far station → alight near gate | PASS (was FAIL pre-fix) |
| Police | chaos raises stars, HUD "WANTED **" shows, ram keeps heat, reset clears | PASS |
| Food | chai heals + charges wallet, stall prompt visible | PASS |
| Pause | open pauses tree, resume unpauses, settings round-trip | PASS |
| Death | KO triggers fade respawn, control + HP restored at landmark | PASS |
| Busted | down-while-wanted → fine charged, heat cleared, control restored | PASS |
| Save/Load | save.json round-trips cash; CONTINUE offered; continue restores cash + position | PASS |
| Corrupt save | garbage file reads back empty; title boots clean, no CONTINUE trap | PASS |

34 functional checks green after the fix; the 5 pre-fix fails were 1
real metro bug + 4 harness bugs in the sweep script itself (wrong HUD
glyph expectation, wrong settings-panel var name, busted-path invoked in
the wrong order).

## Notes for future sweeps

- Boot-time dwell (4.5 s) is the only reliable instant-board window;
  otherwise the full leg takes ~13 s.
- `uv1_triplanar` warnings from `pbr_textures.gd` are pre-existing log
  noise, not script errors; they do not trip the CI error gate.
- Sweep harness lives in `.agent/sweep168.gd` (gitignored); this file is
  the published record.
