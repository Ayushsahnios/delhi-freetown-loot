# QA Sweep 2 — post-overhaul regression audit (issue #191)

Date: 2026-10-29 · Lane D · headless Godot 4.7.2 against `main.tscn`
via the sweep-2 scripted driver (title → start → move → crowd zones →
day-cycle coherence → teleports → vehicle → metro → police → food →
pause → map & waypoints → death → busted → save/load → corrupt-save
paths), plus the
CI frame-time budget gate run AT the new crowd strips and a
day/dusk/night capture pass at the bazaar. Verdict lines print
`SWEEP191 PASS/FAIL`. **Result: 62/62 checks green — no functional
regressions from the realism / world / audio / crowd / map waves.**
Re-run against `0c4b9d3` (master just after the #189 map & waypoints
merge) so the new map screen rides the same audit.

## What was re-verified (sweep-1 stages, all green)

Title + 3 portrait viewports, CONTINUE gating, spawn/ground, walking,
10-spot teleport settle (worst y-drift < 2.5 m), parked-auto board →
drive → exit, **full metro board→ride→alight cycle (the #179
midpoint-stall fix holds)**, police chaos → stars → HUD → reset, chai
purchase, pause/settings round-trip, death respawn, busted fine flow,
save/load round-trip, corrupt-save robustness.

## New sweep-2 stages

| Stage | Checks | Result |
|---|---|---|
| Crowd zones (#192) | bazaar zone awake with 60+ visible shoppers; all positions finite and street-level; crowd walking, not frozen; horn scatter panics nearby walkers | PASS |
| Day/dusk/night (#164) | forced noon → dusk → night: env/fog/lamp values finite at every phase; street lamps off at noon (0.00) and glowing at night (2.1); window emission off at noon, warm at night; HUD clock formats | PASS |
| Map & waypoints (#189) | M opens a north-up city map that pauses the tree; tap sets a waypoint at the tapped spot and the minimap mirrors it; close unfreezes; routing chevron aims at the mission-or-waypoint focus and hides inside 14 m; waypoint auto-clears within 8 m; tapping the pin clears it | PASS |
| Corrupt save, path A (#177) | garbage primary + backup present → `read()` falls back to backup, cash restored, title boots clean | PASS |
| Corrupt save, path B | garbage primary + no backup → `read()` empty, no CONTINUE trap | PASS |

## Frame-time budget at the new density (issue #167 gate)

240 frames, 90 warmup, 22 ms budget, LOD on, measured at the strips
the crowd wave filled (not just default spawn):

| Position | avg ms | p95 ms | Verdict |
|---|---|---|---|
| Spawn | 7.88 | 12.16 | PASS |
| Bazaar strip (-57,75) | 7.81 | 12.63 | PASS |
| CP strip (-17,75) | 7.45 | 11.74 | PASS |

The +50% walker wave (#192) did not break the simulation budget.

## Notes for future sweeps

- Three initial "fails" were harness-side, not game bugs: two stale
  corrupt-save expectations (sweep 1 predated the #177 backup
  rotation — falling back to the backup is the DESIGNED behavior) and
  one flaky horn-scatter probe (zone shoppers spawn ≥ 26 m from the
  player while the horn radius is 18 m, so scattering from the exact
  zone centre can hit zero walkers; the check now stands at the
  nearest visible walker and is deterministic).
- Headless dummy display boots a 64x64 root window regardless of the
  project's 1280x720 setting, so full-rect HUD controls (the city map)
  collapse at 64 px. The driver force-sizes the map to 960x720 before
  the tap checks — harness-only; real windows and CI render lay out
  correctly.
- CI remains the authoritative visual gate (gameplay screenshots +
  issue-152 portrait-distinctness exit code); the day/dusk/night
  lighting coherence above is the headless complement.
- Sweep driver lives in `.agent/sweep191.gd` (gitignored); this file
  is the published record.
