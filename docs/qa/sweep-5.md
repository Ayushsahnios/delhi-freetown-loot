# QA Sweep 5 (part 1 — pre-wave baseline) — issue #296

Date: 2026-11-04 · Lane D · headless Godot 4.7.2 against `master` @
`32cfe59` (post model-swap 1a #299 / asset pipeline #298 / vehicle-body
evaluation #297). Scope note: only the "1a" vendoring has landed — the
four candidate humans (`assets/characters/candidates/`, Quaternius
Modular packs, CC0) are **not wired into crowds/legends/portraits/interiors
yet**, so the full post-swap audit (new models in live scenes) runs when
the remaining swap wave (#291–#294) merges. Per the plan documented on
the issue (2026-11-04 00:30 UTC), this run executes the **trimmed core**
that fits one shift: baseline triple-verify, perf gates at peak density,
save round-trip, 30-min soak, abbreviated notes. The full capture matrix
(day/dusk/night + Diwali) and wired-model audit stay deferred.

## Baseline (triple verify on fresh master @ 32cfe59)

- Headless `--import` → exit 0. The four vendored GLBs import clean
  (no errors, no import-log noise).
- Smoke `--quit-after 5` → exit 0, **zero** `SCRIPT ERROR|ERROR:` lines.
- Hygiene grep → clean (single pre-existing, triaged false positive: the
  OIDC permission keyword in `.github/workflows/export-web.yml`, excluded
  by CI's own hygiene scan since #32; sweep-4 triage stands).

## Asset pipeline + license audit (#298/#299 code read)

- `scripts/asset_gate.sh` → `verdict=PASS (licenses present, 13676KB
  within budget)` — 48 MB / 12 MB budgets hold with the candidates in.
- `candidates/LICENSE.txt` correctly documents the Quaternius Modular
  Men/Women packs as **pre-QAL CC0** (QAL governs only post-2026-08-28
  releases) with source URLs and retrieval note. No Mixamo, no
  commercial content — spot-checked against the LICENSES.md policy.
- **Finding (fixed here):** the central `LICENSES.md` register had no row
  for the new candidates directory (only the folder-local LICENSE.txt,
  which the gate checks). Added the missing register row so the
  attribution surface stays single-source.

## Perf gates (peak density, real game, headless)

| Gate | Result | Budget | Verdict |
|---|---|---|---|
| CI festival gate `--frames 120 --warmup 45 --festival` | avg 8.39 ms, p95 11.50 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90` (LOD live) | avg 10.39 ms, p95 15.55 ms | 22.0 ms | PASS |

Both comfortably inside the #167 budget; the vendored candidates add no
tick cost (they are inert until wired — as expected, and now measured).

## Save round-trip

`save_check.tscn` → `verdict=PASS` (hp float, pos array, missions dict,
nested chars all round-trip; corrupt-save paths covered by the same gate
as CI).

## 30-minute soak (reused sweep-4 driver `.agent/soak273.tscn`)

(driver notes: mem field is labeled `mem_kb` but reports **bytes** —
sweep-4 documented this; verdicts below recomputed from raw ticks)

- Ran to the driver's formal verdict print this time (unlike sweep-4's
  early reap): **21 ticks, t=60 → 1740 s (~29 min)**.
- Zero `SCRIPT ERROR` / `ERROR:` lines in the ~3.9 k-line log.
- Orphan nodes **0 at every tick** — no node leaks across the landmark
  hops (LOD wake/sleep, crowd zones, fleet traffic, day cycle).
- Static memory 198.96 → 201.71 MB (**+2.75 MB** over 29 min; last-10-min
  drift 0.58 MB) — matches sweep-4's benign +2.7 MB warmup profile, no
  leak signature.
- Walkers stable at 66 all session, `player_sane=true` at every sample,
  `day_t` cycling coherently (240 s/day, clean wraps).
- Driver-printed verdict: `passes=2 fails=1` (exit 7). The single FAIL is
  the **known `mem_kb`-reports-bytes mislabel** (triaged sweep-4): the
  driver scored the +2,746,816-**byte** drift as "+2746816 KB" against a
  KB-tuned budget. Recomputed from raw ticks (same method as sweep-4):
  **PASS** — stated as recomputed, not driver-printed.

## Findings + triage

1. `LICENSES.md` register missing the candidates row — **fixed in this
   PR** (docs-only one-liner).
2. `uv1_triplanar_enabled` SpatialMaterial remap warnings (~370/session)
   — pre-existing since the PBR-weathering wave, re-triaged in sweep-4
   as benign noise; still the top cleanup candidate, unchanged.
3. Wired-model audit + day/dusk/night + Diwali capture matrix — deferred
   until the swap wave (#291–#294) lands; re-run trimmed core + capture
   pass there. Full v5 scope (~3h) still needs owner OK per the
   long-task rule.

**Acceptance (trimmed scope): all green; findings triaged.** #296 stays
open for the post-wave audit leg.

## Post-#304 refresh (2026-11-06, master @ 32af400)

First trimmed-core re-run after the first wired CC0 slice landed
(#302 human lineup, #303 triplanar fix, #304 pharmacy/dhaba/chai
furniture). Same gates, same method as part 1.

- Baseline triple verify: `--import` exit 0; smoke `--quit-after 5`
  exit 0 with **zero** `SCRIPT ERROR|ERROR:` lines; hygiene grep clean
  apart from the sweep-4-triaged OIDC keyword false positive.
- **#303 verified in-engine:** `uv1_triplanar` remap warnings are now
  **0 per session** in a fresh smoke boot (was ~370/session at the
  sweep-4/part-1 count). Top cleanup candidate from finding 2 closed by
  measurement, not just by review.
- Asset gate: `verdict=PASS` — 13,880 KB within budget (13,676 KB at
  part 1; +204 KB for the vendored 8-piece furniture set, license docs
  present in `assets/props/furniture/LICENSE.txt` + `LICENSES.md`).
- Save round-trip: `verdict=PASS`, exit 0 (the two logged `Parse JSON`
  errors are the gate's own corrupt-save payloads doing their job).

### Perf gates (post-wiring)

| Gate | Result (re-measured 2026-11-06 ~09:40 UTC) | Part-1 result | Budget | Verdict |
|---|---|---|---|---|
| Festival `--frames 120 --warmup 45` | avg 12.30 ms, p95 16.38 ms | 8.39 / 11.50 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90` (LOD live) | avg 11.96 ms, p95 15.29 ms | 10.39 / 15.55 ms | 22.0 ms | PASS |

Frame cost is up ~1.5–2 ms vs part 1 (the wired furniture + human
lineup now render in-world; part 1 measured them inert). Still >5 ms
under the #167 budget headroom on both gates. Numbers above are from
this run's own gate invocations (session-local run logs); the earlier
in-flight perf numbers from the interrupted 07:35–08:30 UTC session
left no surviving logs, so they were discarded and re-measured rather
than trusted.

Festival density picks up ~1.6 ms avg from the wired furniture
(bookcase/stool/table MeshInstances + chai stools now build at world
gen) and default improves slightly — both far inside the #167 budget.
Headless cannot see renderer-side cost; the draw-call audit stays on
the post-wave capture leg.

### 30-min soak (post-wiring)

- 22 ticks, t=60 → 1740 s (29 min; reaped ~1 min early by an external
  SIGTERM — no formal verdict print, verdicts recomputed from ticks
  per the sweep-4 method).
- Zero `SCRIPT ERROR` / `ERROR:` lines in the log.
- Orphan nodes **0 at every tick**; walkers steady at 66;
  `player_sane=true` at every sample; `day_t` cycling coherently.
- Static memory 201,249 → 203,146 KB = **+1,897 KB over 29 min**
  (last-10-min drift ~380 KB) — same benign warmup profile as part 1
  (+2.75 MB), no leak signature.

**Acceptance (post-#304 leg): all green.** Remaining #296 legs:
wired-model audit + day/dusk/night + Diwali capture matrix once the
rest of the wave (#291/#292/#294) lands.

## Capture leg — aimed-capture matrix + vision audit (2026-11-07, refs #296)

Setup: post-wiring master lineage (`dea3b28` + the `--look` aimed-capture
flag from this PR; runtime code otherwise identical to master). xvfb +
software GL via `scripts/screenshot.gd`. NOTE: the Nov 1-14 festival
window is active by date, so every capture includes Diwali dressing;
there is no `--no-festival` capture knob yet (proposal below).

### Matrix results (rc = engine exit 0, PNG written)

| Vantage / time | rc | Notes |
|---|---|---|
| bazaar day / dusk / night | 0 ×3 | via /tmp runner lineage |
| cp day / dusk / night | 0 ×3 | aimed captures (`--look`) |
| chandni-day | 0 | aimed |
| purani-night | 0 | aimed; festival lights read well |
| gate-day | INCOMPLETE | engine reaped at the shift wrap mid world-build (log ends at station-yard mesh build, no PNG) |

8 of 9 planned shots landed; raw PNGs live in the lane workdir
(`.agent/sweep5cap/`, gitignored) — reproducible with the flags above.

### Vision audit findings (LLM pass over the 8 PNGs + pharmacy test shot)

1. **Day/dusk frames washed out** — sky blows to white haze, background
   detail lost; worst at bazaar (HUD 19:59 reads as flat noon haze).
   Suspect exposure/tone-mapping under the compatibility renderer +
   software GL (#104 lineage); needs a hardware-GL cross-check before
   code changes — flagged, not fixed here.
2. **Dusk grade mismatch** — evening hours render a daylight grade.
3. **Duplicated identical green foliage blobs** on stall tops (bazaar
   day + dusk) — same asset instanced twice symmetric.
4. **Festival-light coverage gap** — purani-night shows glowing strings
   (best frame); pharmacy awning dots render unlit; cp/bazaar night have
   none despite the "Diwali rush!" ticker.
5. **Weather-state mismatch** — pharmacy test shot renders rain streaks
   while the HUD weather line reads "Clear".
6. **Wallet/rent arithmetic** — DAY'S BOOKS shows Rent −120 with wallet
   Rs 0 (clamped display or a real bug — needs an economy check).
7. **Twin desk props** duplicated symmetric at the cp spawn.

Triage: none block the current master lineage; all deferred to the
post-wave audit leg. Follow-up proposals: `--no-festival` capture knob,
night festival-light pass at cp/bazaar, de-dup foliage blobs, dusk
grade fix, weather-state check.

### Next shift

Complete gate-day + the remaining baseline vantages (purani-day,
chandni-dusk, gate-night vs `docs/screenshots/` baselines), then run the
full post-wave audit once #292-#294 land.

## Capture leg completion — final 4 matrix shots + baseline deltas (2026-11-07, refs #296)

Second shift of the capture leg (master @ `f8608c7`). Same setup: xvfb +
software GL via `scripts/screenshot.gd`, aimed captures with `--tp/--look`,
festival window still date-active (Diwali dressing in every frame).

### Matrix completion (rc = engine exit 0, PNG written)

| Vantage / time | Flags | rc | PNG |
|---|---|---|---|
| gate-day | tp 167,-170 · look 167,-201 · day 0.5 | 0 | 421 KB |
| purani-day | tp -102,75 · look -109,75 · day 0.5 | 0 | 636 KB |
| chandni-dusk | tp -56,75 · look -63,75 · day 0.8 | 0 | 582 KB |
| gate-night | tp 167,-170 · look 167,-201 · day 0.0 | 0 | 367 KB |

**Capture matrix now 12/12** (8 prior + 4 here, gate-day recovered from the
reaped shot). Raw PNGs + engine logs in `.agent/sweep5cap/` (gitignored);
reproducible with the flags table above.

### Vision audit vs `docs/screenshots/` baselines

1. **Night/dusk renders correctly in the new aimed shots and BEATS the
   baselines** — chandni-dusk shows a true dark-blue evening with warm
   emissive stall lamps, Hindi signboards and visible festival string
   lights/bunting; gate-night frames the floodlit arch head-on against a
   dark sky with lit windows. Both old baseline night frames are
   washed-out white. The earlier "dusk grade mismatch" finding is NOT
   reproduced by the aimed `--day 0.8` capture (dark evening grade
   rendered correctly) — likely a vantage/exposure artifact of the
   earlier bazaar dusk shot; hardware-GL cross-check proposal stands.
2. **Day washout persists (finding 1 confirmed again)** — gate-day is
   heavily desaturated into pale sepia/cream with no visible shadow
   direction; consistent with the #104-lineage exposure/tone-map issue
   under compatibility + software GL. Flagged, not fixed.
3. **Weather-state mismatch confirmed (second sighting)** — faint
   vertical rain streaks in gate-day while HUD reads Day · Clear; the
   pharmacy test-shot report from the last shift is no longer a
   one-off. Needs a weather-state check (proposal below).
4. **Framing notes (tooling, not art regressions)** — gate-day: the
   over-shoulder cam puts the player mesh large in frame at this offset;
   purani-day: tp -102,75 lands inside the old-city courtyard enclosure
   (dome overhead, boxed-in vantage) — use a street-corner offset next
   time to match the baseline vantage.
5. **purani-day duplicates** — twin identical blue stall canopies
   flanking the player; matches the prior de-dup-foliage/stall-props
   follow-up (de-dup pass proposal).
6. Minor: gate-night bottom third near-black (flat dark ground), lone
   walker with odd proportions at plaza center.

Triage: none block master; items 2/3/5 fold into the existing follow-up
proposals (hardware-GL cross-check, weather-state check, de-dup pass)
which stay queued for the post-wave audit leg.

**Acceptance: matrix complete (12/12), audit deltas recorded.** Remaining
#296 scope unchanged: full post-wave audit leg once #292-#294 land.

## Post-#306 refresh (2026-11-07, master @ `6bea43c`)

Re-measured gates after the market-goods slice (#306: CC0 produce
crates wired into bazaar clusters) — the first in-world geometry the
post-#304 numbers predate. #307/#308 were tooling/docs-only and don't
affect runtime. Same gates, same method as the post-#304 leg.

- Baseline triple verify: `--import` exit 0; smoke `--quit-after 5`
  exit 0 with zero `SCRIPT ERROR|ERROR:` lines; hygiene grep clean
  apart from the sweep-4-triaged CI-permission false positive (and the
  gitignored `.agent/MISSION.md` itself, uncommitted).
- Save round-trip (`save_check.tscn`): `verdict=PASS`, exit 0.

### Perf gates (post-market-goods)

| Gate | Result (re-measured 2026-11-07 ~09:55 UTC) | Post-#304 | Budget | Verdict |
|---|---|---|---|---|
| Festival `--frames 120 --warmup 45` | avg 11.95 ms, p95 20.38 ms | 12.30 / 16.38 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90` (LOD live) | avg 10.32 ms, p95 14.51 ms | 11.96 / 15.29 ms | 22.0 ms | PASS |

Festival avg is flat-to-slightly-better (run-to-run noise band), but
festival **p95 rose 16.38 → 20.38 ms** — the produce crates add
peak-frame cost at festival density exactly where the budget measures.
Default improved on both metrics. Both gates PASS; festival p95
headroom is now ~1.6 ms — flagged as a **watch item** for the
post-wave leg: remaining wave slices (#292-#294) add more geometry,
and if p95 trends past ~21 ms the festival budget itself needs a look.

### 30-min soak (post-market-goods)

Vendored `tools/qa/soak273.tscn` driver (units-fixed per #301), 30 min
headless on this branch's tree (`6bea43c` + docs-only edits, runtime =
master): **SUMMARY passes=3 fails=0, 25 ticks, zero
`SCRIPT ERROR|ERROR:` lines.**

- Player alive and playing after 30 min — PASS.
- Orphan-node drift +0 (0 → 0) — PASS.
- Static-memory drift +1754 KB (202,927 → 204,682 KB) vs the 200,000 KB
  drift budget (~0.9% used) — PASS. +744 KB of it is first-minute
  warmup; the remaining ~+1.0 MB accrues near-linearly over 28 min.
- Walkers steady at 66 the whole run; day_t cycling 0.08→0.83 normally.

Units postmortem: the first soak attempt this leg (11:25 UTC) launched
the old gitignored `.agent/soak273.gd` lineage, which prints raw
`MEMORY_STATIC` bytes as `mem_kb` — the exact mislabel #301 fixed in
the vendored driver. It false-FAILED at "+1761924 KB" (actually
+1.7 MB of benign warmup drift). The stale `.agent` copy is now
units-patched to match the vendored one; `tools/qa/soak273.tscn`
remains the canonical driver.

**Acceptance (post-#306 leg): all green, one watch item.** Remaining
#296 scope unchanged: full post-wave audit leg once #292-#294 land.
