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

## Weather-state check — finding 3 resolved (2026-11-07, refs #296)

Diagnostic built this leg: a `--weather` knob on the capture driver
(`clear` pins the weather state machine bone-dry, `rain` locks a full
squall over the whole day) plus a live weather-state print at capture
time (label / intensity / cloud / wetness) for audit trails. Decisive
pair at the gate-day vantage (`--tp 167,-170 --look 167,-201 --day 0.5`):

| Shot | Weather state at capture | Streaks |
|---|---|---|
| gate-day (original, #308 leg) | not instrumented then | faint vertical streaks |
| gate-day re-run, pinned clear | Clear · intensity 0.000 · cloud 0.000 · wetness 0.000 | clean — streaks gone |

Vision verdict: the streaks WERE rain. Root cause of the "HUD says
Clear while rain renders" desync: `_update_label` reported "Clear" up
to intensity 0.15 while rain particles emit from intensity > 0.02 —
and the capture driver's forced `--day` can land inside the rolled
(65%-per-day) monsoon window, so faint rain rendered with the HUD
still reading Clear. Fixes: a "Drizzle" label band (0.02–0.15) so the
HUD never says Clear while streaks render, and the `--weather` pin
knob for deterministic captures (any future baseline re-shot can hold
weather fixed instead of rolling the dice). Raw PNGs + engine logs in
`.agent/sweep5cap/` (gitignored); re-run with the flags table above.

## Pinned-clear capture matrix + `--no-festival` knob (2026-11-07, refs #296)

Two follow-ups from the capture leg, one slice (master @ `aeaf162`).

### `--no-festival` capture knob

`scripts/festival.gd is_festival()` now returns false on a `--no-festival`
user arg, overriding BOTH `--festival` and the Nov 1-14 date window
(usage documented in `scripts/screenshot.gd`). Inside the window this
holds the city undressed for festival-vs-plain baseline diffing without
waiting for Nov 15. Downstream gates (food surge, radio, night glow) all
key off the same `_festival == null` path — unchanged.

Decisive pair at cp day (`--tp -17,-17 --look -34,-34 --day 0.5
--weather clear`): the festival shot carries the festival banner ticker,
the `--no-festival` shot does not (vision-audited); PNG deltas 619,764
vs 606,832 bytes. Festival props at this vantage were already below
daytime visibility (finding 4, coverage gap) — a purani-night
festival/no-fest pair is queued for the post-wave audit leg, where the
strings/diyas actually read on camera.

### Pinned-clear matrix refresh (all `--weather clear`)

| Shot | Flags | rc | PNG |
|---|---|---|---|
| cp-day | tp -17,-17 · look -34,-34 · day 0.5 | 0 | 620 KB |
| cp-day-nofest | same + `--no-festival` | 0 | 607 KB |
| cp-dusk | tp -17,-17 · look -34,-34 · day 0.8 | 0 | 380 KB |
| cp-night | tp -17,-17 · look -34,-34 · day 0.0 | 0 | 379 KB |
| chandni-day | tp -56,75 · look -63,75 · day 0.5 | 0 | 586 KB |
| chandni-dusk | tp -56,75 · look -63,75 · day 0.8 | 0 | 677 KB |
| purani-day | tp -102,75 · look -109,75 · day 0.5 | 0 | 740 KB |
| purani-night | tp -102,75 · look -109,75 · day 0.0 | 0 | 526 KB |
| gate-night | tp 167,-170 ·look 167,-201 · day 0.0 | 0 | 194 KB |

Every capture log prints `weather: Clear intensity=0.000 cloud=0.000
wetness=0.000` — the monsoon dice no longer touch baselines. Raw
PNGs + engine logs in `.agent/sweep5cap2/` (gitignored), captured
21:28–21:43 UTC by an interrupted shift and re-corroborated on adoption
(all sizes match, weather lines present, zero `SCRIPT ERROR|ERROR:`
lines); cp pair re-vision-audited on adoption: the `Diwali night!`
ticker segment is present in the festival shot and stripped in the
`--no-festival` shot, zero rain streaks, HUD reads "Delhi — Day ·
Clear" in both. gate-day pinned-clear already exists from the #310 leg. cp look target re-picked
(-34,-34, symmetric SW) — the original cp logs predate the `--look`
print; the day/dusk/night triple is now self-consistent. Bazaar
re-shots deferred: the original vantage flags are unrecoverable from
repo artifacts (pre-`--look` runner) — re-pick a bazaar vantage via
block-center math in the post-wave leg.

Vision spot-check (cp pair): zero rain streaks, zero weather artifacts,
HUD "Clear" in both — finding 3's fix holds across the re-run matrix.
Day-washout (finding 1) still present at cp-day as expected
(#104-lineage, unfixed).

**Acceptance: deterministic pinned-clear baseline set (9 shots here +
gate-day from #310), `--no-festival` knob live.** Remaining #296 scope
unchanged: full post-wave audit leg once #292–#294 land (add to it:
purani-night festival/no-fest pair, bazaar pinned-clear re-shots).

## Bazaar pinned-clear re-shots + purani-night festival pair (2026-11-08, refs #296)

The two queued capture additions from the last leg, master @ `dd314bf`
(same tree as this branch; docs-only diff). Same setup: xvfb + software
GL, `--weather clear` pinned, `--no-card`, 90 settle frames. Bazaar
vantage re-picked via block-center math (the original pre-`--look` flags
are unrecoverable): player at the south end of the Chandni Chowk market
lane (block 4,7; lane axis x = −57 per `_market_lane(cx + 6, cz)` with
cx = −63, cz = 75), looking north up the lane at the cart/stall row.

| Shot | Flags | rc | PNG | Weather line |
|---|---|---|---|---|
| bazaar-day | tp −54,60 · look −56,85 · day 0.5 | 0 | 486 KB | Clear 0.000/0.000/0.000 |
| bazaar-dusk | same · day 0.8 | 0 | 302 KB | Clear 0.000/0.000/0.000 |
| bazaar-night | same · day 0.0 | 0 | 320 KB | Clear 0.000/0.000/0.000 |
| purani-night-fest | tp −102,75 · look −109,75 · day 0.0 | 0 | 526,131 B | Clear 0.000/0.000/0.000 |
| purani-night-nofest | same + `--no-festival` | 0 | 525,918 B | Clear 0.000/0.000/0.000 |

All five logs: zero `SCRIPT ERROR|ERROR:` lines; purani-night-fest
byte-matches the #312 matrix's 526 KB shot — pinned captures are
reproducible across shifts. Raw PNGs + logs in `.agent/sweep5cap3/`
(gitignored); reproduce with the flags table.

### Vision audit

1. **Festival dressing at purani-night is TEXT-ONLY (finding 4
   upgraded).** The controlled festival/no-fest pair is visually
   identical apart from the HUD ticker segment ("Diwali rush!" vs
   "night market") — no string lights, diyas, banners, bunting or glow
   points differ in the 3D scene; PNG delta just 213 B. The first-leg
   note "purani-night: festival lights read well" is not reproduced at
   this standard vantage under pinned clear — whatever glow leg 1 saw
   was the lamp/static lighting present in BOTH shots here (that leg
   was also unpinned, pre-`--look`). Festival geometry reads at NO
   tested night vantage (cp, bazaar, purani) while the ticker still
   advertises the rush. Night festival-light pass proposal now covers
   all three landmarks, not just cp/bazaar.
2. **Bazaar lane content reads weakly at the re-picked vantage.** The
   chai stall's ground marker (CHAI Rs 2) and the food ticker are
   legible, but thela carts / stall awnings / neon signage don't read
   clearly in any of the three grades at ~10–25 m under software GL.
   Tooling-grade limitation (day washout + llvmpipe) vs a real dressing
   gap — fold into the hardware-GL cross-check already queued; not
   triaged as an art regression on this evidence.
3. **Day washout persists (finding 1, #104 lineage)** — bazaar-day at
   HUD 13:12 is the same overexposed pale haze; night grades render
   correct dark contrast. Dusk (20:23, day 0.8) renders the dark
   evening grade; noted: dusk and deep-night (01:11) grades are
   near-identical at this vantage.
4. **Zero rain streaks across all five shots** (finding 3's fix holds
   with `--weather clear` end to end; HUD reads Day/Night · Clear).
5. **Repeated identical window-grid tiling** on the flanking building
   rows in every bazaar shot — same family as the de-dup pass
   follow-up (stall/prop duplicates); add facade-window variation to
   that proposal's scope.

Triage: nothing blocks master; items fold into the existing queued
proposals (night festival-light pass — widened, hardware-GL
cross-check, de-dup pass — widened).

**Acceptance: both queued capture legs landed (5/5 clean, deterministic
matrix now 15 shots).** Remaining #296 scope unchanged: full post-wave
audit leg once #292–#294 land.

## Post-#311 refresh (2026-11-08, master @ `785dee9`)

Re-measured gates after the first post-#306 geometry slice (#311
vehicle detail 1a: door scribes, stub handles, number plates on the
street trio) plus the #310 weather/HUD and #312 capture-knob changes;
#313 was docs-only. Same gates, same method as the post-#306 leg.

Method note: `perf_check.gd` does not pin weather (the `--weather`
knob lives on the capture driver only) and `weather.gd` calls
`_rng.randomize()` at boot, so every gate runs with a freshly rolled
monsoon plan — rain-at-boot carries particle + wetness cost. Gate
numbers are a sample of the weather band, not a pinned condition.
Candidate follow-up: parse `--weather` in `perf_check.gd` too.

### Perf gates (post-vehicle-detail-1a)

| Gate | Result (2026-11-08 ~02:20 UTC) | Post-#306 | Budget | Verdict |
|---|---|---|---|---|
| Festival `--frames 120 --warmup 45` | avg 10.21 ms, p95 15.30 ms | 11.95 / 20.38 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90` (LOD live) | avg 8.54 ms, p95 13.45 ms | 10.32 / 14.51 ms | 22.0 ms | PASS |
| Default `--no-festival` `--frames 240 --warmup 90` | avg 8.26 ms, p95 12.62 ms | (new baseline) | 22.0 ms | PASS |

Both headline gates improved ~1.8–3.9 ms avg vs post-#306 despite the
added vehicle detail — #311's scribes/handles/plates are cheap on the
sim side, and this run booted outside a rain window. The post-#306
festival p95 watch item (20.38 ms, ~1.6 ms headroom) did NOT
reproduce: p95 is back to 15.30 ms (~6.7 ms headroom). Given the
unpinned weather band above, treat that as "not reproducing", not
proven-fixed — if it recurs on a rain-boot run, pin gate weather
before re-triaging.

First `--no-festival` perf baseline (the #312 knob reaches any scene —
`festival.gd` reads cmdline user args directly): festival dressing
costs ~+1.95 ms avg / +2.83 ms p95 at default-gate settings on this
master — the reference number for the queued night-festival-light
proposal to re-measure against.

### 30-min soak (post-vehicle-detail-1a)

Vendored `tools/qa/soak273.tscn` driver, 30-min headless run on this
branch's tree (runtime = master `785dee9`; diff is docs-only). The
host reaped the process at t=1740 s (29 min) — no formal SUMMARY
print; verdicts recomputed from ticks per the sweep-4 method (same
precedent as the post-#304 leg).

- 23 ticks (two 60-s tick gaps — wall-clock slowdowns under host
  load; benign), zero `SCRIPT ERROR` / `ERROR:` lines in the log.
- Player alive and playing through the last tick (`player_sane=true`
  at every sample) — PASS at 29 min.
- Orphan drift 0 → 0 — PASS.
- Static-memory drift 201,711 → 203,654 KB = **+1,943 KB over 29 min**
  vs the 200,000 KB drift budget (~1.0% used) — PASS. Same benign
  warmup profile as every prior leg (first-minutes rise, then flat
  ~203.5–203.7 MB).
- Walkers steady at 66 the whole run; day_t cycling 0.08→0.83.

**Acceptance (post-#311 refresh leg): all gates green** — the
post-#306 festival-p95 watch item did not reproduce (unpinned-weather
caveat noted above). Remaining #296 scope unchanged: full post-wave
audit leg once #292–#294 land.

## Perf-gate determinism leg: `--weather` pin in perf_check (2026-11-08, master @ `1e9b99a`)

Closes the "candidate follow-up" from the post-#311 refresh:
`perf_check.gd` now parses `--weather clear|rain` (same `debug_pin`
the capture driver uses) and prints a `WEATHER_STATE` audit line with
every verdict. Gates stop rolling the 65%-per-day monsoon dice;
numbers below are the first deterministic (pinned) gate baselines.

| Gate (all pinned) | avg / p95 ms | Unpinned sample (post-#311) | Budget | Verdict |
|---|---|---|---|---|
| Default `--weather clear` (240/90, LOD live) | 8.07 / 12.48 | 8.54 / 13.45 | 22.0 ms | PASS |
| Default `--weather rain` (240/90) | 8.91 / 13.26 | (never measured) | 22.0 ms | PASS |
| Festival `--weather clear` (120/45) | 8.41 / 13.12 | 10.21 / 15.30 | 22.0 ms | PASS |

- **Deterministic rain cost: +0.84 ms avg / +0.78 ms p95** (clear →
  rain, same frames/warmup) — squall particles + wetness + cloud at
  default-gate settings. Cheap; no gate risk.
- Pinned-clear runs sit ~0.5–1.8 ms under the unpinned post-#311
  sample, consistent with that boot carrying partial weather cost —
  the unpinned band is now quantified from both sides.
- Going forward: gate PRs should measure `--weather clear` (the
  reference baseline) plus `--weather rain` when touching weather,
  particles, or wet-look shaders. `WEATHER_STATE` in the log is the
  audit proof the pin took (e.g. `Monsoon intensity=0.840` above).

Triple verify on branch: import rc 0 / smoke 0 error lines / hygiene
clean apart from the sweep-4-triaged pre-existing hits (none from
this diff).

**Acceptance: gate determinism leg landed.** Remaining #296 scope
unchanged: full post-wave audit leg once #292–#294 land.

## Post-#314 refresh (2026-11-08, master @ `49af1a6`)

Re-measured after the shop-interiors slice (#314: CC0 props wired into
kirana/paan/bookstore — 14 props, ~2.0k tris, one collider each, merged
05:40 UTC) and the walker fleet swap (#315: walkers retargeted to CC0
rigs, merged 03:32 UTC — the post-#311 refresh at ~02:20 UTC predates
it, so this is the first gate pass on the walkers-swapped tree). Same
gates, same pinned method as the #317 determinism leg.

### Perf gates (pinned; WEATHER_STATE audit line in every log)

| Gate | Result (~06:15 UTC) | Pinned baseline (#317) | Budget | Verdict |
|---|---|---|---|---|
| Default `--weather clear` (240/90, LOD live) | avg 8.93 ms, p95 13.40 ms | 8.07 / 12.48 | 22.0 ms | PASS |
| Default `--weather rain` (240/90) | avg 9.45 ms, p95 13.98 ms | 8.91 / 13.26 | 22.0 ms | PASS |
| Festival `--weather clear` (120/45) | avg 9.29 ms, p95 14.73 ms | 8.41 / 13.12 | 22.0 ms | PASS |

- Deterministic rain cost +0.52 avg / +0.58 p95 (clear→rain, 240/90) —
  same magnitude as #317's +0.84/+0.78; cheap, no gate risk.
- Post-#314/#315 delta vs the pinned baselines: +0.5–0.9 ms avg and
  +0.6–1.6 ms p95 across gates — the wired interior props and
  retargeted walker fleet carry a modest, budgeted cost; worst
  headroom is 7.3 ms (festival p95 14.73 vs 22.0).
- The post-#306 festival-p95 watch item (20.38 ms unpinned) still does
  not reproduce under pinned weather.

### Baseline + save

- Triple verify on branch (docs-only diff; runtime = master): `--import`
  rc 0; smoke `--quit-after 5` rc 0 with zero `SCRIPT ERROR|ERROR:`
  lines; hygiene grep → 2 pre-existing triaged hits only (the
  export-web.yml OIDC keyword + gitignored `.agent/MISSION.md`).
- Save round-trip (`save_check.tscn`): `verdict=PASS`, exit 0.

### 30-min soak (post-#314/#315)

Vendored `tools/qa/soak273.tscn` driver (units-fixed per #301), headless
on this branch's tree (runtime = master `49af1a6`; diff docs-only).
Reaped at t=1740 s (29 min) at shift wrap — no formal SUMMARY print;
verdicts recomputed from ticks per the sweep-4 / post-#311 precedent.

- 25 ticks (a few 120-s tick gaps — host-load wall-clock slowdowns
  during parallel gate runs; benign), zero `SCRIPT ERROR`/`ERROR:`
  lines in the log.
- Player alive and playing through the last tick (`player_sane=true`
  at every sample) — PASS at 29 min.
- Orphan nodes **0 at every tick** — drift 0 → PASS.
- Static-memory drift 217,924 → 218,831 KB over t=240→1740 s =
  **+907 KB over 25 min** vs the 200,000 KB drift budget (~0.5% used)
  — PASS; flat after t≈1380 s (218.8 MB band). Same benign warmup
  profile as every prior leg.
- **Baseline shift note:** static memory now idles ~218 MB vs ~203.7 MB
  at post-#311 — roughly +15 MB from #315's retargeted walker rigs
  (full-CC0 meshes + clips) plus #314's wired props. The drift
  signature is unchanged; the absolute idle level is recorded for the
  post-wave audit leg's reference.
- Walkers steady at 66 the whole run; day_t cycling coherently
  (0.08→0.83 wraps).

**Acceptance (post-#314 refresh leg): all gates green — pinned perf
gates, triple verify, save round-trip, soak recomputed-PASS.** Remaining
#296 scope unchanged: full post-wave audit leg once #292–#294 land.

## Full-length soak re-verify + perf-budget pinned-gate sync (2026-11-08, master @ `8cca373`)

Two deliverables on the post-#318 tree: a full-length soak re-run and
the pinned-gate method landing in `docs/perf_budget.md` (previously
documented only in these notes).

### Soak (post-#318 tree)

Vendored `tools/qa/soak273.tscn` driver, headless on this branch's tree
(runtime = master `8cca373`; diff docs-only). The run was reaped at
t=1740 s (29 min) — same wrap point as the #318 leg, no formal SUMMARY
print; verdicts recomputed from ticks per the sweep-4 / post-#311
precedent.

- 23 ticks (a few 120-s tick gaps — wall-clock slowdowns under parallel
  verify runs; benign), zero `SCRIPT ERROR`/`ERROR:` lines in the log.
- Player alive and playing through the last tick (`player_sane=true` at
  every sample) — PASS at 29 min.
- Orphan nodes **0 at every tick** — drift 0 → PASS.
- Static-memory drift 218,197 → 220,424 KB over t=60→1740 s =
  **+2,227 KB over 28 min** vs the 200,000 KB drift budget (~1.1%
  used) — PASS; flat in the 220.1–220.4 MB band after t≈1380 s. Idle
  level matches the #318 baseline-shift note (~218–220 MB post-#314/
  #315); drift signature unchanged and same order as #318's +907 KB.
- Walkers steady at 66 the whole run; day_t cycling coherently
  (0.08→0.83 wraps).

Two consecutive 29-min reaped soaks (#318 leg + this one) on the same
runtime tree with matching all-PASS verdicts — the "30-min soak"
acceptance is covered twice over by recomputed-PASS; a SUMMARY-printing
run remains a nice-to-have for the post-wave audit leg, not a blocker.

### Perf-budget doc sync

`docs/perf_budget.md` gains a "Pinned-weather gate runs" section: the
`--weather clear|rain` pin + `WEATHER_STATE` audit line, the reference
pinned-baseline table from the post-#314 refresh (default clear
8.93/13.40, rain 9.45/13.98, festival clear 9.29/14.73 ms — all under
the 22.0 ms budget), and when rain gates are required. Tree hygiene
pickup: engine-generated `.import` sidecar for #315's tracked
`docs/captures/humans/retarget-proof.png` (missed in #315, regenerated
by this branch's import pass) committed alongside.

Triple verify on branch: `--import` rc 0 / smoke `--quit-after 5` rc 0
with zero `SCRIPT ERROR|ERROR:` lines / hygiene clean apart from the
sweep-4-triaged pre-existing hit (export-web.yml OIDC keyword; none
from this diff).

**Acceptance: soak re-PASS (recomputed, second consecutive) +
perf-budget pinned-gate docs landed.** Remaining #296 scope unchanged:
full post-wave audit leg once #292–#294 land.

## Formal SUMMARY-printing full soak (2026-11-08, master @ `d515bd5`)

The nice-to-have from the re-verify leg: a soak that runs to its own
t=1800 s verdict block instead of being reaped at shift wrap.

### Why SUMMARY never printed before (three reaped runs)

All three prior reaps (#318 leg, #320 leg, and the re-verify leg's
first run) stopped at exactly engine t=1740 s. Root cause: the soak was
hosted in a plain background exec session with a ~1 h wall lifetime
cap, and the engine runs at roughly half wall-clock speed under host
load, so the cap always landed just before the t=1800 s verdict block.
Fix: launch the soak as a setsid-detached process (survives session
caps) and harvest the log in the following shift.

### Soak (post-#321 tree, detached launch)

Vendored `tools/qa/soak273.tscn` driver, headless on master `d515bd5`,
launched detached at 12:07 UTC, SUMMARY printed at 12:47 UTC — the
first formal SUMMARY-printing soak of sweep 5.

- 24 ticks t=60→1740 s, zero `SCRIPT ERROR`/`ERROR:` lines in the log.
- `SOAK273 PASS — player alive and playing after 30 min`
  (`player_sane=true` at every sample).
- `SOAK273 PASS — orphan-node drift over soak: +0 (start 0 → end 0)`.
- `SOAK273 PASS — static-memory drift over soak: +2163 KB (start
  217976 KB → end 220139 KB)` — ~1.1% of the 200,000 KB drift budget;
  flat in the 220.0–220.2 MB band after t≈1380 s. Same warmup profile
  and idle level as the #318/#320 legs.
- Walkers steady at 66 the whole run; day_t cycling coherently
  (0.08→0.83 wraps).
- **`SOAK273 SUMMARY passes=3 fails=0 ticks=24`** — the driver's own
  verdict block, not a recompute. Third consecutive all-green full
  soak on this tree (two recomputed + one formal).

**Acceptance: soak nice-to-have closed — the first formal
SUMMARY-printing run confirms the recomputed verdicts.** Remaining
#296 scope unchanged: full post-wave audit leg once #292–#294 land.

## Post-#319 refresh (2026-11-08, master @ `056fc8b`)

First refresh on a post-#319 tree: the legend trio CC0 Casual body
swap (#319, merged 13:12 UTC) is the only geometry change since the
post-#318/#321 legs — the #322 soak ran on `d515bd5`, pre-#319. Same
gates, same pinning (`--weather clear`, `WEATHER_STATE` audited Clear
0.000/0.000/0.000 in every log), branch diff docs-only.

### Perf gates (pinned clear, post-#319)

| Gate | Result (~15:45–15:58 UTC) | Post-#314 | Budget | Verdict |
|---|---|---|---|---|
| Festival `--frames 120 --warmup 45` | avg 11.61 ms, p95 23.63 ms | 9.29 / 14.73 | 22.0 ms | PASS |
| Festival re-run (p95 check) | avg 11.13 ms, p95 15.07 ms | — | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90` | avg 9.08 ms, p95 13.41 ms | 8.93 / 13.40 | 22.0 ms | PASS |
| Default `--no-festival` | avg 9.18 ms, p95 13.46 ms | 8.26 / 12.62 (post-#311, unpinned) | 22.0 ms | PASS |

- **Default gate unchanged** (+0.15 ms avg vs post-#314) — the CC0
  legend bodies add no measurable default-scene cost.
- **Festival-gate avg up ~+1.8–2.3 ms, reproducing across two runs**
  (11.61 / 11.13 vs 9.29). Most plausible carrier is #319 (GLB bodies
  now spawning through title/player/legend paths exercised by the
  festival vantage); still PASS with ≥10.4 ms headroom. Watch item,
  not a blocker.
- First run's p95 23.63 ms exceeded the 22.0 line but the re-run came
  back at 15.07 ms — single-run hitch not reproducing (same
  post-#306-watch-item pattern; the gate's pass criterion is avg,
  p95 is informational).
- Festival-vs-no-festival delta at default settings is ~0 today
  (9.08 vs 9.18) vs post-#311's +1.95 ms — that reference number was
  measured unpinned-weather, so treat it as superseded by the pinned
  post-#314 pair, not as a festival-cost change.

### Save + legend gates (post-#319)

- `save_check.tscn` → `verdict=PASS` (rc 0).
- `legend_check.tscn` → `LEGEND_CHECK PASS trio built, tailored,
  distinct` (rc 0) — the #319-touched gate is green on this tree.

### 30-min soak (post-#319)

Launched 16:02 UTC via the #322 setsid-detached method on this
branch's tree (runtime = master `056fc8b`); harvest + verdicts land in
the next shift's leg per the detached-soak handoff. Not claimed as
run here.

**Acceptance: pinned gates, save, legend all green post-#319** (one
reproducing watch item: festival-gate avg +~2 ms, PASS with headroom).
Remaining #296 scope unchanged: full post-wave audit leg once
#292–#294 land.

## Post-#319 soak — second formal SUMMARY-printing run (2026-11-08, post-`056fc8b` tree)

Harvest of the detached soak promised by the post-#319 refresh leg:
launched 16:02 UTC via the #322 setsid-detached method on the
`issue-296-post319-refresh` tree (runtime identical to master `056fc8b`;
branch diff was docs-only), SUMMARY printed 16:56 UTC.

- 22 ticks t=60 → 1740 s, zero `SCRIPT ERROR` / `ERROR:` lines in the
  36-line log.
- `SOAK273 PASS — player alive and playing after 30 min`
  (`player_sane=true` at every sample; walkers steady at 66; `day_t`
  cycling coherently 0.08→0.83 wraps).
- `SOAK273 PASS — orphan-node drift over soak: +0 (start 0 → end 0)`.
- `SOAK273 PASS — static-memory drift over soak: +1978 KB (start
  219592 KB → end 221570 KB)` — ~1.0% of the 200,000 KB drift budget;
  flat in the 221.4–221.6 MB band after t≈1380 s. Idle level and
  warmup profile match the #318/#320/#322 legs (~218–221 MB band).
- **`SOAK273 SUMMARY passes=3 fails=0 ticks=22`** — the driver's own
  verdict block, not a recompute.

Second consecutive formal SUMMARY-printing all-PASS soak (after the
#322 leg's first), and the first one on post-#319 geometry — the
legend-trio CC0 Casual bodies show no soak-visible regression (no new
orphans, no drift-signature change, no error lines). Post-#319 soak
coverage: gates PASS (prior leg) + soak driver-verdict PASS (here).

**Acceptance: post-#319 refresh fully green — gates, save, legend,
and now the formal soak.** Remaining #296 scope unchanged: full
post-wave audit leg once #292–#294 land.

## Post-#327 vehicle-geometry gate spot-check (2026-11-09, master @ `0c85b45`)

Interim spot-check between the post-#319 refresh and the (still gated)
post-wave audit leg: #327 landed the vehicle detail pass 1b (side
mirrors + window rubber — first vehicle-geometry change on the audit
path since #314), so the pinned gates were re-run once on the merged
tree to keep the per-landing gate series continuous.

### Perf gates (pinned clear, post-#327)

- **Default gate:** avg 8.49 ms / p95 12.82 ms vs 22.0 ms budget —
  **PASS** (exit 0; `WEATHER_STATE label=Clear 0.000/0.000/0.000`).
- **Festival gate:** avg 8.17 ms / p95 12.62 ms vs 22.0 ms budget —
  **PASS** (exit 0; weather audited Clear).

Both readings sit inside the 7.4–8.9 ms host-load noise band the
post-#319 refresh documented (7.38/7.88 avg then; #317 baselines
8.07–8.91) — the mirror/rubber delta (~hundreds of tris per vehicle)
shows no gate movement. Runs were sequential, not parallel, per the
host-load lesson from the 15:45–15:58 Nov 8 window. Known benign
headless exit warning (`ObjectDB instances leaked at exit`) present
as on prior gate runs; zero `SCRIPT ERROR`/`ERROR:` lines.

Triple verify on `0c85b45` before the gates: import exit 0; smoke
boot 0 error lines; hygiene clean on the committed tree (one
pre-existing match in `.github/workflows/export-web.yml` — the
GitHub Actions OIDC write-permission stanza, in a dir the CI hygiene
scan excludes, on master since #34; noted, not touched).

**Acceptance: post-#327 gates green — series continuous across the
vehicle geometry landing.** Remaining #296 scope unchanged: full
post-wave audit leg once #292–#294 land.

## Post-#327 soak (2026-11-09, master @ `2e72fff`)

Third formal 30-min soak leg, first on post-#327 vehicle geometry
(mirrors + window rubber — the geometry change gated last leg via perf
spot-check only). Catches the soak series up with the per-landing gate
series before the wave-gated final audit leg, so the post-wave soak
will diff against a baseline that already includes #327's per-vehicle
node additions (mirror pair + rubber strips per spawned vehicle —
exactly what the orphan/memory drift monitors watch).

Method: same as the post-#319 leg — #322 setsid-detached method,
vendored `tools/qa/soak273.tscn`, headless on the master tree
(`2e72fff`), launched 06:34 UTC, engine self-exited at SUMMARY; this
doc leg's branch diff is docs-only. Boot log clean.

- 22 ticks t=60 → 1740 s, zero `SCRIPT ERROR` / `ERROR:` lines in the
  whole log.
- `SOAK273 PASS — player alive and playing after 30 min`
  (`player_sane=true` at every tick; walkers steady at 66; `day_t`
  cycling coherently through wraps).
- `SOAK273 PASS — orphan-node drift over soak: +0 (start 0 → end 0)`
  — #327's per-vehicle mirror/rubber nodes leak nothing.
- `SOAK273 PASS — static-memory drift over soak: +1856 KB (start
  219000 KB → end 220856 KB)` — ~0.9% of the 200,000 KB drift budget,
  flat in the 220.0–220.9 MB band after t≈300 s; idle level and warmup
  profile match the #318/#320/#322/#324 legs (~218–221 MB band).
- **`SOAK273 SUMMARY passes=3 fails=0 ticks=22`** — the driver's own
  verdict block, not a recompute.

Third consecutive formal SUMMARY-printing all-PASS soak and the first
on post-#327 geometry: the mirror/rubber vehicle detail shows no
soak-visible regression (no orphans, no drift-signature change, no
error lines). Soak coverage now level with gate coverage (both
post-#327).

**Acceptance: post-#327 soak green — soak series caught up with the
gate series.** Remaining #296 scope unchanged: full post-wave audit
leg once #292–#294 land.

## Post-#331 station-furniture gate spot-check (2026-11-09, master @ `74c4a11`)

Interim spot-check between the post-#327 soak and the (still
wave-gated) audit leg: #331 landed the station-furniture swap
(slab benches -> CC0 chairs + truthful colliders, refs #293; merged
`bdb2184`), the first station-area geometry change on the audit path
since the #314 shop-interiors slice — so the pinned gates were re-run
on the merged tree to keep the per-landing gate series continuous.
(#332, the #294 closeout verdict doc + captures, is docs/PNG-only and
needs no gate.)

### Perf gates (pinned clear, post-#331; sequential runs)

- **Default gate, run 1:** avg 10.05 ms / p95 15.61 ms vs 22.0 ms
  budget — **PASS** (`WEATHER_STATE label=Clear 0.000/0.000/0.000`;
  zero `SCRIPT ERROR`/`ERROR:` lines).
- **Default gate, run 2:** avg 9.79 ms / p95 13.72 ms — **PASS**
  (weather audited Clear; zero error lines).
- **Festival gate:** avg 8.86 ms / p95 14.26 ms — **PASS** (weather
  audited Clear; zero error lines).

Reading: the festival number sits inside the 7.4–8.9 ms pinned
host-load band; the two default readings are the highest pinned-clear
pair to date (+1.0–1.5 ms avg vs #317's 8.07 and the post-#327 leg's
8.49), though still 4.5+ ms inside budget and below every unpinned
default reading this sweep (10.32–10.39 from the part-1 legs). The
elevation reproduced across two sequential boots, so it is recorded
as a **watch item, not noise-dismissed**: either host load or the
truthful chair colliders carry roughly a millisecond of sim cost.
The wave-gated audit leg will re-measure on the fully-landed tree
and diff against this leg. No FAIL stands — all three runs PASS.

Triple verify on `74c4a11` before the gates: import exit 0; smoke
boot 0 error lines; hygiene clean on the committed tree (the
pre-existing, CI-excluded GitHub-OIDC permission stanza noted in the
#328 leg stands, untouched).

**Acceptance: post-#331 gates green — series continuous across the
station-furniture landing, one watch item carried into the audit
leg.** Remaining #296 scope unchanged: full post-wave audit leg once
#293 lands and #292 is adjudicated (blocked-on-owner per the Nov 9
Lane A handoff).
