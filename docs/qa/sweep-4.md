# QA Sweep 4 — v1.0 soak + post-Launch-Wave audit (issue #273)

Date: 2026-10-31 · Lane D · headless Godot 4.7.2 against `master` @
`65f9de6` (post soundscape #274 / fleet #276 / quality toggle #277 /
de-box cluster 1 #278). Scope note: the still-open Launch Wave items
(Diwali #263, finales #264, night neon #265, concourse #184, onboarding
#271) are **not** in master yet — their gate runs when they land. This
sweep audits everything merged and re-runs the full sweep-1/2 regression
plus the 30-minute soak the issue asks for.

## Baseline (triple verify on fresh master)

Headless import exit 0; 300-frame smoke with zero `SCRIPT ERROR|ERROR:`
lines; hygiene grep clean except one pre-existing false positive —
the workflow OIDC permission key inside `.github/workflows/export-web.yml` (a GitHub
Actions permission keyword, in master since #32; CI's own hygiene scan
deliberately excludes `.github/`). Triaged, not a leak.

## 30-minute v1.0 soak

Driver `.agent/soak273.tscn` (uncommitted, per lane practice): boots the
real game, starts legend 1, dismisses the first-boot card, then hops the
camera+player across every landmark every 2 minutes while sampling
orphan count, static memory, live walkers, day clock and player sanity
each minute.

- **Ran 29+ minutes clean** (the session was reaped ~50 s before the
  30:00 deadline, just short of the driver's formal verdict print — so
  verdicts below are recomputed from the 29 recorded ticks, stated
  plainly rather than claimed as driver-printed).
- Orphan nodes: **0 at every tick** — no node leaks across 15 landmark
  hops exercising LOD wake/sleep, crowd zones, fleet traffic, day cycle.
- Static memory: 194.83 MB → 197.55 MB (**+2.7 MB** over 29 min), flat
  after warmup (last 10 min drift < 0.2 MB) — no leak signature.
- Walkers stable at 66, player finite/valid at every sample, `day_t`
  cycling coherently (240 s/day, clean midnight wraps).
- Zero `SCRIPT ERROR` / `ERROR:` in the ~3.9 k-line log.
- Driver-side note for future sweeps: the tick line labels memory `mem_kb`
  but reports **bytes** (the 200 MB drift budget would false-fail as
  200 KB), and hop/tick window nesting skips some 120 s ticks. Fix the
  driver before trusting its printed drift verdicts; the tick data
  itself is sound.

## Full sweep-2 regression (re-run twice)

Run A: 60/62 green. Run B: 61/62 green. The two stage fails are **stale
harness expectations, not game bugs** — both root-caused:

| Stage | Symptom | Root cause | Verdict |
|---|---|---|---|
| food | run A FAIL (chai cost 30), run B PASS (cost 20) | monsoon demand premium (#205) bumps the cart price during a squall; driver asserted the flat base price. Surge pricing works as designed | harness-stale; driver updated to `_price()` |
| metro | FAIL both runs, exactly 13.5 m off | #218 moved alighting to the **platform** (`platform_alight_pos`), driver still measures against the pre-#218 street-gate anchor `alight_pos()`. Board/dwell/alight/controls all pass; placement is correct platform-level behaviour | harness-stale; driver updated to platform anchor |

Everything else green in both runs: title + portraits, CONTINUE gating,
spawn/walk, 10-spot teleport settle, parked-auto board/drive/exit, full
metro cycle, police escalation→stars→HUD→reset, chai purchase + stall
prompt, pause/settings round-trip (now including the #277 QUALITY row),
death respawn, busted fine, **save/load round-trip post-everything**,
corrupt-save paths A/B, crowd zones, forced day/dusk/night coherence,
map + waypoints.

## Launch Wave code audits (read the diffs, all merged commits)

- **#277 quality toggle** — `tier_scale` applied *before* the city build
  (LOW boots short-tier); runtime switch via `rescale()` from stashed
  `lod_end_base` metas (HIGH round-trip restores exact bases, no drift);
  late-spawned traffic tiers at the live scale; AUTO watcher armed only
  in-game and freed on explicit presets. Logic clean; `quality_check`
  4-leg gate shipped with the PR.
- **#276 fleet** — heavy three spawn as rolled kinds on their own
  MultiMesh pools (tanker 5%, truck 8%, tempo 12%), shared wheel specs,
  smoke-stack puffs anchored at stack mouths. Despawn rides the existing
  instance pool; no per-frame allocations spotted; soak confirms zero
  orphan/memory drift with the fleet live.
- **#274 soundscape** — bell/shankh/azan one-shots gated by day-hour
  windows with once-per-day flags reset on the `day_t` midnight wrap;
  dialogue duck applied to sacred voices; inverse-distance capping at
  110 m. Clean.
- **#278 de-box** — geometry-only (`delhi_dressing3.gd`); smoke clean.

## Log-noise triage (non-blocking)

~373 `WARNING: Godot 3.x SpatialMaterial remapped parameter not found:
uv1_triplanar_enabled` per session from `pbr_textures.gd
apply_weathering` (via meshtools/street_furniture/breakdown/metro
builders). Benign remap warnings, pre-existing since those systems
landed, but the noisiest thing in an otherwise clean log — filed as a
cleanup candidate, not a blocker.

## Acceptance

All functional checks green (the two stage fails above are confirmed
driver-stale, and the drivers are fixed for future runs); soak monitors
flat; remaining findings triaged: soak-driver unit bug (fixed next run),
SpatialMaterial warning cleanup (candidate follow-up), Diwali/capture
pass deferred until #263 lands. Issue #273 closes with this record.
