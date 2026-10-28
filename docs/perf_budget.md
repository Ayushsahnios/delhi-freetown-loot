# Headless frame-time budget (perf gate)

Issue #167. The CI perf gate boots the real game headless, plays a
fixed window of frames, and fails the build when the average frame
exceeds the budget. A density or systems PR that silently tanks the
simulation can no longer land green.

## How it runs

```
godot --headless --path . res://scenes/perf_check.tscn \
    -- --frames 240 --warmup 90 --budget 22
```

- Boots the full main scene (world build, traffic, peds, police,
  missions, HUD), starts the first character, dismisses the first-boot
  card, settles `--warmup` frames, then wall-clocks `--frames` frames.
- Verdict line: `PERF_CHECK frames=… avg_ms=… p95_ms=… budget_ms=… verdict=PASS|FAIL`
- Nonzero exit on FAIL; CI additionally greps for `verdict=PASS`.

## Budget

**22.0 ms average headless frame** (DEFAULT_BUDGET_MS in
`scripts/perf_check.gd`).

Measured baseline on the dev box, master + gate, LOD off
(`--no-lod`): **avg 6.9 ms, p95 10.8 ms** over 240 frames. The budget
is ~3x that measured average — room for GitHub runner hardware being
slower and for normal variance, while a real simulation blowup (a
ticked system that doubles or triples cost) still trips it. If the
gate ever fails without an obvious cause, re-measure locally with
`--no-lod` before moving the budget; the number is a regression
tripwire, not a target.

## What the gate catches — and what it does not

- **Catches:** simulation cost — GDScript tick work, physics steps,
  spawning storms, per-frame allocations. This is what density PRs
  (street saturation, crowd counts) endanger first.
- **Does not catch:** renderer-side cost. The headless renderer is a
  dummy: draw calls, fill rate and materials are invisible to it.
  Renderer-side protection comes from the draw-distance tiers
  (`scripts/lod.gd`) plus code review; `perf_check.gd --draws` under a
  real renderer (xvfb + opengl3) samples the draw-call count for
  before/after comparison when tuning tiers:

  ```
  xvfb-run -a godot --path . --rendering-driver opengl3 \
      res://scenes/perf_check.tscn -- --draws --frames 100 --warmup 50 [--no-lod]
  ```

## Draw-distance tiers (issue 167)

`scripts/lod.gd` assigns every static geometry instance a renderer-side
visibility range — culled instances cost no draw call and no fill, and
there is no per-frame LOD script spending frames to save frames.

| Tier | Range | Applies to |
|------|-------|------------|
| SMALL | 90 m  | clutter, signage, street-level detail |
| MID   | 160 m | street dressing, furniture, trees |
| BIG   | 320 m | merged per-district buildings |

Landmarks, roads, the ground and the sky are deliberately untiered —
they are the far skyline. The camera far plane is trimmed to 800 m
(the 506 m city's 715 m diagonal still fits corner-to-corner).

## Updating the budget

1. Measure master headless: `perf_check.tscn -- --no-lod` (3 runs, take
   the worst average).
2. Set the budget to ~3x that worst average, rounded up.
3. Say why in the PR that changes it.
