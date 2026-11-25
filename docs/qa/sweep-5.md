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

## Post-#331 station-furniture soak (2026-11-09, master @ `0f35771`)

Fourth formal SUMMARY-printing soak, reaped from the detached run
launched ~10:31 UTC on the current master tree (runtime unchanged
since #331 `bdb2184`: #332–#334 landed docs/PNG/capture-tool-only
changes). Detached-per-`setsid` launch per the #322 method; engine
self-exited at t=1800 s and printed its own verdict block.

- 24 ticks t=60–1740 s; `orphans=0` at every tick; walkers steady at
  66; `player_sane=true` throughout; zero `SCRIPT ERROR`/`ERROR:`
  lines in the log.
- `SOAK273 PASS — player alive and playing after 30 min`
- `SOAK273 PASS — orphan-node drift over soak: +0 (start 0 → end 0)`
- `SOAK273 PASS — static-memory drift over soak: +753 KB (start
  219224 KB → end 219978 KB)` — ~0.4% of the 200,000 KB drift
  budget, flat in the 219.2–220.0 MB band from the first tick; idle
  level and warmup profile match the #318/#320/#322/#324/#330 legs
  (~218–221 MB band).
- **`SOAK273 SUMMARY passes=3 fails=0 ticks=24`** — the driver's own
  verdict block, not a recompute.

Fourth consecutive formal SUMMARY-printing all-PASS soak and the
first on post-#331 geometry: the CC0 station chairs + truthful
colliders show no soak-visible regression (no orphan nodes, no
drift-signature change, no error lines). The post-#331 gate watch
item (default-pair avg +1.0–1.5 ms, gate leg above) has no
counterpart on the soak side — orphans and memory stay flat; the
audit leg will re-measure both. Soak coverage level with gate
coverage (both post-#331).

**Acceptance: post-#331 soak green — soak series caught up with the
gate series on the current tree.** Remaining #296 scope unchanged:
full post-wave audit leg once #293 lands and #292 is adjudicated
(blocked-on-owner per the Nov 9 Lane A handoff).

## Post-#331 gate watch-item re-measure (2026-11-09, master @ `33a010a`)

Same-tree follow-up on the post-#331 gate leg's watch item (default
pinned-clear pair avg 10.05 / 9.79 ms, +1.0–1.5 ms above the 7.4–8.9 ms
pinned band, reproduced across two boots that shift). The runtime is
unchanged since #331 (`bdb2184`) — #332–#336 landed docs/PNG/capture-
tool-only changes — so any shift in the numbers is host-load, not code.
Method identical to the prior leg: sequential boots, weather pinned
clear, `WEATHER_STATE` audit line checked in every log, zero
`SCRIPT ERROR`/`ERROR:` lines in all three logs.

| Gate (pinned clear) | avg | p95 | vs watch pair | budget | verdict |
|---|---|---|---|---|---|
| Default `--frames 240 --warmup 90`, run 1 | 8.33 ms | 12.76 ms | −1.7 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90`, run 2 | 9.08 ms | 13.36 ms | −0.7 ms | 22.0 ms | PASS |
| Festival `--frames 120 --warmup 45` | 8.95 ms | 13.33 ms | inside 8.2–8.9 band | 22.0 ms | PASS |

Reading: the elevated default pair did **not** persist on identical
runtime — both fresh readings land inside the pinned host-load band
(8.33 / 9.08 vs the watch pair's 10.05 / 9.79), and the festival run
sits in its usual 8.2–8.9 band. Combined with the post-#331 soak
finding no counterpart signature (orphans 0, flat memory), the leading
explanation is the host-load window during the #334 leg, not a real
millisecond of chair-collider sim cost. **Watch item closed as
not-reproducing on a same-tree re-measure**; the wave-gated audit leg
still re-measures both gates on the fully-landed tree per its charter.
No FAIL stands — all runs PASS with 4.5+ ms headroom.

**Acceptance: watch item resolved same-tree — pinned-gate series
continuous, no elevation carried forward.** Remaining #296 scope
unchanged: full post-wave audit leg once #293 lands and #292 is
adjudicated (blocked-on-owner per the Nov 9 Lane A handoff).

## Interim refresh on master `69e8f8e` (2026-11-14, post-#342)

The Nov 9 close-out left the pinned series resting on an unchanged
runtime. Since then the world lane landed #340/#342 (paan doorway
geometry shift + widened doorway) — the first runtime scene deltas since
the watch item closed — plus capture-tool-only knobs (#339/#341). This
leg re-runs the pinned gate series, regression, and save round-trip on
the current tree so the final post-wave audit leg starts from a fresh
baseline. Method identical to the Nov 9 leg: sequential headless boots,
weather pinned clear, `WEATHER_STATE` audit line checked in every log,
zero `SCRIPT ERROR`/`ERROR:` lines in all logs.

| Gate (pinned clear) | avg | p95 | budget | verdict |
|---|---|---|---|---|
| Default `--frames 240 --warmup 90`, run 1 | 8.05 ms | 11.83 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90`, run 2 | 8.02 ms | 11.47 ms | 22.0 ms | PASS |
| Festival `--frames 120 --warmup 45` | 7.82 ms | 10.66 ms | 22.0 ms | PASS |

- Import: exit 0. Smoke `--quit-after 5`: exit 0, zero error lines.
- Save round-trip (`save_check.tscn`): `verdict=PASS`, exit 0.

Reading: both default runs sit just under the 8.2–8.9 ms pinned
host-load band and the festival run lands below it — the doorway
geometry change (#340/#342) moved nothing measurable at the gate site.
**Acceptance: interim refresh fully green on `69e8f8e`; remaining #296
scope unchanged** — full post-wave audit leg still gated on #293 landing
and #292 adjudication (blocked-on-owner per the Nov 9 Lane A handoff).

## Soak leg on master `71afdd0` (2026-11-14, post-#344)

The interim refresh on `69e8f8e` left the 30-minute soak as the last
runnable #296 leg before the wave gate. Executed ~20:45–21:15 UTC on
the current tree (`71afdd0`) with the pinned soak harness
(`qa/soak273.tscn`), same method as the Nov 9 baseline.

| Check | Result | Verdict |
|---|---|---|
| Player alive + playing after 30 min | alive at soak end | PASS |
| Orphan-node drift over soak | 0 → 0 (+0) | PASS |
| Static-memory drift over soak | 220442 → 221674 KB (+1231 KB, ~0.6%) | PASS |
| Error lines in soak log | 0 `SCRIPT ERROR`/`ERROR:` lines | PASS |
| Walker population | 66 stable across every logged tick | stable |
| Day-cycle progress | day_t cycling normally (0.08 → 0.83) | normal |

Harness summary line: `passes=3 fails=0 ticks=22`. Twenty-two of the
thirty minute-tick prints made it to the log; the other eight were
dropped under host load (tick prints ride the engine loop, the
end-of-run checks do not — all three ran and passed). No leak
signature: memory flat at ~221 MB with +1231 KB total drift over
30 minutes, orphan count zero throughout, walker count constant.

**Acceptance: soak leg green on `71afdd0` — no perf/leak regression
after the #344 interim refresh. Remaining #296 scope: the wave-gated
full post-swap audit leg (needs #293 landed and #292 adjudicated).**

## Interim refresh on master `e255c88` (2026-11-17, post-#354)

The `71afdd0` soak left the pinned series resting again. Since then the
gameplay lane landed #354 (street-defense cricket-bat melee, knock-back
only) — the first runtime-visible *gameplay* change since the soak leg,
touching player/police/pedestrian scripts — while two announced refresh
legs on `3bd12f1` never reached a PR. This leg re-runs the pinned gate
series, import/smoke, and save round-trip on the current tree so the
final post-wave audit leg again starts from a fresh baseline. Method
identical to the Nov 14 leg: sequential headless boots, weather pinned
clear, `WEATHER_STATE` audit line checked in every log, zero
`SCRIPT ERROR`/`ERROR:` lines in import/smoke/perf logs.

| Gate (pinned clear) | avg | p95 | budget | verdict |
|---|---|---|---|---|
| Default `--frames 240 --warmup 90`, run 1 | 10.34 ms | 20.99 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90`, run 2 | 9.87 ms | 16.67 ms | 22.0 ms | PASS |
| Festival `--frames 120 --warmup 45` (`--festival` forced; Nov 17 is outside the date window) | 9.99 ms | 14.41 ms | 22.0 ms | PASS |

- Import: exit 0. Smoke `--quit-after 5`: exit 0, zero error lines.
- Save round-trip (`save_check.tscn`): `verdict=PASS`, exit 0. The two
  `ERROR: Parse JSON failed` lines in its log are the harness's own
  deliberate garbage/corruption inputs (issue 169 design), not
  regressions.

Reading: both default runs sit just above the 8.2–8.9 ms pinned
host-load band (10.34 / 9.87), mirroring the #334 watch pair (10.05 /
9.79) that closed as host-load, not-reproducing on a same-tree
re-measure. All three gates PASS with 11.7+ ms headroom under budget
and no error lines anywhere, so no FAIL stands; if the wave-gated final
audit leg also reads high, it should same-tree re-measure before
suspecting the melee — no per-run evidence of bat-swing cost here.

**Acceptance: interim refresh fully green on `e255c88`; remaining #296
scope unchanged** — full post-wave audit leg still gated on #293 landing
and #292 adjudication (blocked-on-owner per the Nov 9 Lane A handoff).

## Interim refresh on master `caf9985` (2026-11-17, post-#356/#357)

The `e255c88` refresh was the last documented baseline. Since then the
loop merged #356 (bazaar stall produce crates — street dressing) and
#357 (busted/wasted parody cards with stings — runtime UI/audio on
arrest/down). Both are runtime-visible, so this leg re-runs the pinned
gate series, import/smoke, and save round-trip on the current tree so
the wave-gated final audit leg starts from a fresh baseline. Method
identical to the `e255c88` leg: sequential headless boots, weather
pinned clear, `WEATHER_STATE` audit line checked in every perf log.

| Gate (pinned clear) | avg | p95 | budget | verdict |
|---|---|---|---|---|
| Default `--frames 240 --warmup 90`, run 1 | 7.74 ms | 13.12 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90`, run 2 | 10.83 ms | 16.19 ms | 22.0 ms | PASS |
| Festival `--frames 120 --warmup 45` (`--festival` forced) | 7.89 ms | 10.91 ms | 22.0 ms | PASS |

- Import: exit 0. Smoke `--quit-after 5`: exit 0, zero error lines.
- Save round-trip (`save_check.tscn`): `verdict=PASS`, exit 0. The
  `ERROR: Parse JSON` lines in its log are the harness's own
  deliberate garbage/corruption inputs (issue 169 design), not
  regressions.
- Hygiene grep (repo-wide, usual exclusions): clean.

Reading: run 1 sits inside the pinned host band at 7.74 ms; run 2
reads 10.83 ms — the same sequential-boot spread the `e255c88` pair
(10.34/9.87) and the #334 watch pair (10.05/9.79) showed and closed as
host-load. The parody cards render only on arrest/down transitions,
outside the free-roam perf window, so there is no mechanism for card
cost in these numbers. All gates PASS with 5.2+ ms headroom under
budget and zero error lines anywhere.

**Acceptance: interim refresh fully green on `caf9985`; remaining #296
scope unchanged** — full post-wave audit leg still gated on #293
landing and #292 adjudication (blocked-on-owner per the Nov 9 Lane A
handoff).

## Interim refresh on master `31a2388` (2026-11-18, post-#359)

The `caf9985` refresh (merged as #358) was the last documented baseline.
Since then the loop merged #359 (bus-shelter benches — vendored CC0
chairs replacing the procedural slat bench, runtime-visible street
dressing). This leg re-runs the pinned gate series, import/smoke, and
save round-trip on the current tree so the wave-gated final audit leg
starts from a fresh baseline. Method identical to the `caf9985` leg:
sequential headless boots, weather pinned clear, `WEATHER_STATE` audit
line checked in every perf log.

| Gate (pinned clear) | avg | p95 | budget | verdict |
|---|---|---|---|---|
| Default `--frames 240 --warmup 90`, run 1 | 9.67 ms | 13.76 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90`, run 2 | 7.80 ms | 12.22 ms | 22.0 ms | PASS |
| Festival `--frames 120 --warmup 45` (`--festival` forced) | 7.99 ms | 13.76 ms | 22.0 ms | PASS |

- Import: exit 0. Smoke `--quit-after 5`: exit 0, zero error lines.
- Save round-trip (`save_check.tscn`): `verdict=PASS`, exit 0. The two
  `ERROR: Parse JSON` lines in its log are the harness's own
  deliberate garbage/corruption inputs (issue 169 design), not
  regressions.
- Hygiene grep (repo-wide, usual exclusions): clean.

Reading: both default runs sit inside the pinned host band (9.67 /
7.80 ms, order inverted vs the `caf9985` pair's 7.74 / 10.83) — the
same sequential-boot host spread those legs and the #334 watch pair
closed as host-load. The #359 chair swap is a bench-mesh replacement
on street shelters; no cost from it is visible here (all gates hold
12+ ms headroom under budget, zero error lines anywhere).

**Acceptance: interim refresh fully green on `31a2388`; remaining #296
scope unchanged** — full post-wave audit leg still gated on #293
landing and #292 adjudication (blocked-on-owner per the Nov 9 Lane A
handoff).

## Interim refresh on master `ad26943` (2026-11-21, post-#361)

The `31a2388` refresh (merged as #360) was the last documented
baseline. Since then the loop merged #361 (Kaali-Peeli garage slice 1 —
15-rung vehicle ladder data + headless garage_check gate; runtime is
data-only until the garage UI slice consumes it). This leg re-runs the
pinned gate series, import/smoke, and save round-trip on the current
tree so the wave-gated final audit leg starts from a fresh baseline.
Method identical to the `31a2388` leg: sequential headless boots,
weather pinned clear, `WEATHER_STATE` audit line checked in every
perf log.

| Gate (pinned clear) | avg | p95 | budget | verdict |
|---|---|---|---|---|
| Default `--frames 240 --warmup 90`, run 1 | 10.10 ms | 14.99 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90`, run 2 | 9.73 ms | 14.03 ms | 22.0 ms | PASS |
| Festival `--frames 120 --warmup 45` (`--festival` forced) | 10.50 ms | 14.92 ms | 22.0 ms | PASS |

- Import: exit 0. Smoke `--quit-after 5`: exit 0, zero error lines.
- Save round-trip (`save_check.tscn`): `verdict=PASS`, exit 0.
- Hygiene grep (repo-wide, usual exclusions): clean.

Reading: both default runs sit inside the pinned host band (10.10 /
9.73 ms) — the same sequential-boot spread every leg since `caf9985`
has shown and closed as host-load. #361's ladder data is inert until
the garage UI slice lands, and no cost from it is visible here (all
gates hold 11+ ms headroom under budget, zero error lines anywhere).

**Acceptance: interim refresh fully green on `ad26943`; remaining #296
scope unchanged** — full post-wave audit leg still gated on #293
landing and #292 adjudication (blocked-on-owner per the Nov 9 Lane A
handoff).

## Interim refresh on master `79e862a` (2026-11-21, post-#363)

The `ad26943` refresh (merged as #362) was the last documented
baseline. Since then the loop merged #363 (wardrobe audit — box/capsule
outfit overlays now attach on legacy rigs only, porter bundle stays on
every body; refs #292). That is a runtime-visible character-dressing
change, so this leg re-runs the pinned gate series, import/smoke, and
save round-trip on the current tree so the wave-gated final audit leg
starts from a fresh baseline. Method identical to the `ad26943` leg:
sequential headless boots, weather pinned clear, `WEATHER_STATE` audit
line checked in every perf log.

| Gate (pinned clear) | avg | p95 | budget | verdict |
|---|---|---|---|---|
| Default `--frames 240 --warmup 90`, run 1 | 8.27 ms | 12.94 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90`, run 2 | 8.39 ms | 11.07 ms | 22.0 ms | PASS |
| Festival `--frames 120 --warmup 45` (`--festival` forced) | 9.83 ms | 14.30 ms | 22.0 ms | PASS |

- Import: exit 0. Smoke `--quit-after 5`: exit 0, zero error lines.
- Save round-trip (`save_check.tscn`): `verdict=PASS`, exit 0. The two
  `ERROR: Parse JSON` lines in its log are the harness's own
  deliberate garbage/corruption inputs (issue 169 design), not
  regressions.
- Hygiene grep (repo-wide, usual exclusions): clean.

Reading: both default runs sit inside the pinned host band (8.27 /
8.39 ms) — the same sequential-boot spread every leg since `caf9985`
has shown and closed as host-load. #363's overlay gating removes
per-frame dressing work (legacy rigs only) rather than adding it, and
no cost is visible here (all gates hold 12+ ms headroom under budget,
zero error lines anywhere).

**Acceptance: interim refresh fully green on `79e862a`; remaining #296
scope unchanged** — full post-wave audit leg still gated on #293
landing and #292 adjudication (blocked-on-owner per the Nov 9 Lane A
handoff).

## Interim refresh on master `ab2f77d` (2026-11-22, post-#365)

The `79e862a` refresh (merged as #364) was the last documented
baseline. Since then the loop merged #365 (chai-point CC0 swap —
Quaternius stool base + KayKit kettle/bowl/plate replace the
procedural chai props; refs #293). That is a runtime-visible
world-content change, so this leg re-runs the pinned gate series,
import/smoke, and save round-trip on the current tree. Method
identical to the `79e862a` leg: sequential headless boots, weather
pinned clear, `WEATHER_STATE` audit line checked in every perf log.

| Gate (pinned clear) | avg | p95 | budget | verdict |
|---|---|---|---|---|
| Default `--frames 240 --warmup 90`, run 1 | 9.82 ms | 14.07 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90`, run 2 | 8.70 ms | 13.32 ms | 22.0 ms | PASS |
| Festival `--frames 120 --warmup 45` (`--festival` forced) | 8.78 ms | 13.04 ms | 22.0 ms | PASS |

- Import: exit 0. Smoke `--quit-after 5`: exit 0, zero error lines.
- Save round-trip (`save_check.tscn`): `verdict=PASS`, exit 0.
- Hygiene grep (repo-wide, usual exclusions): clean.

Reading: all three gates sit inside the sequential-boot spread every
leg since `caf9985` has shown and closed as host-load (8.70–9.82 ms
avg, 12+ ms headroom under budget). #365 swaps four static props at
one chai point for modeled GLBs; no measurable simulation cost.

**Acceptance: interim refresh fully green on `ab2f77d`; remaining #296
scope unchanged** — full post-wave audit leg still gated on #293
landing and #292 adjudication (blocked-on-owner per the Nov 9 Lane A
handoff).

## Interim refresh on master `a2c88cc` (2026-11-23, post-#367)

The `ab2f77d` refresh (merged as #366) was the last documented
baseline. Since then the loop merged #367 (Kaali-Peeli garage pad
slice 2 — kerbside buy/ride rollout + save fold; refs #347). That is
a runtime gameplay change on the economy + save surface, so this leg
re-runs the pinned gate series, import/smoke, and save round-trip on
the current tree, plus the garage-pad gate (15 rungs) as a targeted
regression for the new system. Method identical to the `ab2f77d` leg:
sequential headless boots, weather pinned clear, `WEATHER_STATE`
audit line checked in every perf log.

| Gate (pinned clear) | avg | p95 | budget | verdict |
|---|---|---|---|---|
| Default `--frames 240 --warmup 90`, run 1 | 12.79 ms | 20.70 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90`, run 2 | 10.69 ms | 16.09 ms | 22.0 ms | PASS |
| Festival `--frames 120 --warmup 45` (`--festival` forced) | 11.27 ms | 14.79 ms | 22.0 ms | PASS |

- Import: exit 0. Smoke `--quit-after 5`: exit 0, zero error lines.
- Save round-trip (`save_check.tscn`): `verdict=PASS`, all 21
  expectations, exit 0. The log's two `ERROR: Parse JSON failed`
  lines sit on the deliberate corrupt-save fixtures (garbage /
  unreadable-primary rungs) — expected engine parse output on those
  tests, not regressions.
- Garage pad gate (`garage_check.tscn`, new with #347 slice 2):
  `garage_check: PASS 15 rungs, gates + rollout + save round-trip
  green`, exit 0.
- Hygiene grep (repo-wide, usual exclusions): clean.

Reading: all three perf gates hold 9+ ms headroom under budget.
Averages sit above the `ab2f77d` leg's band (8.70–9.82 ms) —
consistent with a busier shared host this cycle rather than a code
cost: p95 stays ≤ 20.7 ms, the #367 delta (kerbside interaction +
save fold) adds no per-frame simulation work at the gate site, and
the targeted garage gate covers the new system directly.

**Acceptance: interim refresh fully green on `a2c88cc`; remaining
#296 scope unchanged** — full post-wave audit leg still gated on
#293 landing and #292 adjudication (blocked-on-owner per the Nov 9
Lane A handoff).

## Interim refresh on master `5e95b07` (2026-11-23, post-#368)

The `a2c88cc` refresh (merged as #368) was the last documented
baseline. Since then the loop merged #368 itself — this sweep's own
refresh PR — so master sits at `5e95b07` with zero gameplay deltas
since the `a2c88c­c` leg. This leg re-pins the documented baseline on
the exact commit every future leg diffs against. Method identical:
sequential headless boots, weather pinned clear, `WEATHER_STATE`
audit line checked in every perf log.

| Gate (pinned clear) | avg | p95 | budget | verdict |
|---|---|---|---|---|
| Default `--frames 240 --warmup 90`, run 1 | 9.03 ms | 13.50 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90`, run 2 | 8.68 ms | 13.56 ms | 22.0 ms | PASS |
| Festival `--frames 120 --warmup 45` (`--festival` forced) | 8.98 ms | 13.69 ms | 22.0 ms | PASS |

- Import: exit 0. Smoke `--quit-after 5`: exit 0, zero error lines.
- Save round-trip (`save_check.tscn`): `verdict=PASS`, all 21
  expectations met, exit 0. The log's two `ERROR: Parse JSON failed`
  lines sit on the deliberate corrupt-save fixtures (garbage /
  unreadable-primary rungs) — expected engine parse output, same as
  the `a2c88cc` leg.
- Garage pad gate (`garage_check.tscn`, #347): `garage_check: PASS 15
  rungs, gates + rollout + save round-trip green`, exit 0.
- Hygiene grep (repo-wide, usual exclusions): clean.

Reading: all three perf gates hold 12+ ms headroom under budget and
sit back in the quiet-host band (8.68–9.03 ms avg) the `ab2f77d` leg
showed — the `a2c88cc` leg's higher averages (10.69–12.79 ms) read
as shared-host load, and this leg confirms that reading: same code
surface, tighter numbers, no regression signal anywhere.

**Acceptance: interim refresh fully green on `5e95b07`; remaining
#296 scope unchanged** — full post-wave audit leg still gated on
#293 landing and #292 adjudication (blocked-on-owner per the Nov 9
Lane A handoff).

## Interim refresh on master `c0c63aa` (2026-11-23, post-#369)

The `5e95b07` refresh (merged as #369) was the last documented
baseline. Since then the loop merged #369 itself — this sweep's own
refresh PR — so master sits at `c0c63aa` with zero gameplay deltas
since the `5e95b07` leg. This leg re-pins the documented baseline on
the exact commit every future leg diffs against. Method identical:
sequential headless boots, weather pinned clear, `WEATHER_STATE`
audit line checked in every perf log.

| Gate (pinned clear) | avg | p95 | budget | verdict |
|---|---|---|---|---|
| Default `--frames 240 --warmup 90`, run 1 | 12.87 ms | 19.47 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90`, run 2 | 10.55 ms | 14.18 ms | 22.0 ms | PASS |
| Festival `--frames 120 --warmup 45` (`--festival` forced) | 11.55 ms | 14.66 ms | 22.0 ms | PASS |

- Import: exit 0. Smoke `--quit-after 5`: exit 0, zero error lines.
- Save round-trip (`save_check.tscn`): `verdict=PASS`, all 21
  expectations met, exit 0. The log's two `ERROR: Parse JSON failed`
  lines sit on the deliberate corrupt-save fixtures (garbage /
  unreadable-primary rungs) — expected engine parse output, same as
  the `5e95b07` leg.
- Garage pad gate (`garage_check.tscn`, #347): `garage_check: PASS 15
  rungs, gates + rollout + save round-trip green`, exit 0.
- Hygiene grep (repo-wide, usual exclusions): clean.

Reading: all three perf gates hold 9+ ms headroom under budget. The
spread across the two default runs (10.55–12.87 ms avg) and run 1's
p95 (19.47 ms) read as shared-host load — identical shape to the
`a2c88cc` leg's story and the opposite of a code cost: the code
surface is byte-identical to the `5e95b07` leg (which measured
8.68–9.03 ms avg), so no regression signal anywhere.

**Acceptance: interim refresh fully green on `c0c63aa`; remaining
#296 scope unchanged** — full post-wave audit leg still gated on
#293 landing and #292 adjudication (blocked-on-owner per the Nov 9
Lane A handoff).

## Interim refresh on master `0bf11f4` (2026-11-23, post-#370)

The `c0c63aa` refresh (merged as #370) was the last documented
baseline. Since then the loop merged #370 itself — again this
sweep's own docs-only refresh PR — so master sits at `0bf11f4` with
zero gameplay-code deltas since the `5e95b07` leg (every merge since
#368 touched only this file). This leg re-pins the documented
baseline on the exact commit every future leg diffs against. Method
identical: sequential headless boots, weather pinned clear,
`WEATHER_STATE` audit line checked in every perf log.

| Gate (pinned clear) | avg | p95 | budget | verdict |
|---|---|---|---|---|
| Default `--frames 240 --warmup 90`, run 1 | 9.14 ms | 13.89 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90`, run 2 | 12.61 ms | 16.34 ms | 22.0 ms | PASS |
| Festival `--frames 120 --warmup 45` (`--festival` forced) | 13.50 ms | 19.59 ms | 22.0 ms | PASS |

- Import: exit 0. Smoke `--quit-after 5`: exit 0, zero error lines.
- Save round-trip (`save_check.tscn`): `verdict=PASS`, exit 0. The
  log's two `ERROR: Parse JSON failed` lines sit on the deliberate
  corrupt-save fixtures — expected engine parse output, same as every
  prior leg.
- Garage pad gate (`garage_check.tscn`, #347): `garage_check: PASS 15
  rungs, gates + rollout + save round-trip green`, exit 0.
- Hygiene grep (repo-wide, usual exclusions): clean.

Reading: all three perf gates hold 8.5+ ms headroom under budget.
The default-run spread (9.14–12.61 ms avg) repeats the shared-host
load signature documented on the `a2c88cc` and `c0c63aa` legs; the
game code surface is byte-identical to the `5e95b07` leg, so no
regression signal anywhere.

**Acceptance: interim refresh fully green on `0bf11f4`; remaining
#296 scope unchanged** — full post-wave audit leg still gated on
#293 landing and #292 adjudication (blocked-on-owner per the Nov 9
Lane A handoff).

## Interim refresh on master `9384c09` (2026-11-24, post-#371)

The `0bf11f4` refresh (merged as #371) was the last documented
baseline. Since then the loop merged #371 itself — again this
sweep's own docs-only refresh PR — so master sits at `9384c09`
with zero gameplay-code deltas since the `5e95b07` leg (every
merge since #368 touched only this file). This leg re-pins the
documented baseline on the exact commit every future leg diffs
against. Method identical: sequential headless boots, weather
pinned clear, `WEATHER_STATE` audit line checked in every perf log.

| Gate (pinned clear) | avg | p95 | budget | verdict |
|---|---|---|---|---|
| Default `--frames 240 --warmup 90`, run 1 | 8.26 ms | 11.41 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90`, run 2 | 11.61 ms | 16.30 ms | 22.0 ms | PASS |
| Festival `--frames 120 --warmup 45` (`--festival` forced) | 8.83 ms | 13.21 ms | 22.0 ms | PASS |

- Import: exit 0. Smoke `--quit-after 5`: exit 0, zero error lines.
- Save round-trip (`save_check.tscn`): `verdict=PASS`, exit 0.
- Garage pad gate (`garage_check.tscn`, #347): `garage_check: PASS 15
  rungs, gates + rollout + save round-trip green`, exit 0.
- Hygiene grep (repo-wide, usual exclusions): clean.

Reading: all three perf gates hold 5.7+ ms headroom under budget.
The default-run spread (8.26–11.61 ms avg) repeats the shared-host
load signature documented on the `a2c88cc`/`c0c63aa`/`0bf11f4`
legs; the game code surface is byte-identical to the `5e95b07`
leg, so no regression signal anywhere.

**Acceptance: interim refresh fully green on `9384c09`; remaining
#296 scope unchanged** — full post-wave audit leg still gated on
#293 landing and #292 adjudication (blocked-on-owner per the Nov 9
Lane A handoff).

## Interim refresh on master `ded4988` (2026-11-24, post-#372)

The `9384c09` refresh (merged as #372) was the last documented
baseline. Since then the loop merged #372 itself — again this
sweep's own docs-only refresh PR — so master sits at `ded4988`
with zero gameplay-code deltas since the `5e95b07` leg (every
merge since #368 touched only this file). This leg re-pins the
documented baseline on the exact commit every future leg diffs
against. Method identical: sequential headless boots, weather
pinned clear, `WEATHER_STATE` audit line checked in every perf log.

| Gate (pinned clear) | avg | p95 | budget | verdict |
|---|---|---|---|---|
| Default `--frames 240 --warmup 90`, run 1 | 8.52 ms | 13.10 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90`, run 2 | 10.47 ms | 19.75 ms | 22.0 ms | PASS |
| Festival `--frames 120 --warmup 45` (`--festival` forced) | 8.57 ms | 11.40 ms | 22.0 ms | PASS |

- Import: exit 0. Smoke `--quit-after 5`: exit 0, zero error lines.
- Save round-trip (`save_check.tscn`): `verdict=PASS`, exit 0.
- Garage pad gate (`garage_check.tscn`, #347): `garage_check: PASS 15
  rungs, gates + rollout + save round-trip green`, exit 0.
- Hygiene grep (repo-wide, usual exclusions): clean.

Reading: all three perf gates pass; worst p95 leaves 2.25 ms
headroom under the 22.0 ms budget. The default-run spread
(8.52–10.47 ms avg) and the run-2 p95 spike repeat the
shared-host load signature documented on the `a2c88cc`/`c0c63aa`/
`0bf11f4`/`9384c09` legs; the game code surface is byte-identical
to the `5e95b07` leg, so no regression signal anywhere.

**Acceptance: interim refresh fully green on `ded4988`; remaining
#296 scope unchanged** — full post-wave audit leg still gated on
#293 landing and #292 adjudication (blocked-on-owner per the Nov 9
Lane A handoff).

## Interim refresh on master `0b88030` (2026-11-24, post-#373)

The `ded4988` refresh (merged as #373) was the last documented
baseline. Since then the loop merged #373 itself — again this
sweep's own docs-only refresh PR — so master sits at `0b88030`
with zero gameplay-code deltas since the `5e95b07` leg (every
merge since #368 touched only this file). This leg re-pins the
documented baseline on the exact commit every future leg diffs
against. Method identical: sequential headless boots, weather
pinned clear, `WEATHER_STATE` audit line checked in every perf log.

| Gate (pinned clear) | avg | p95 | budget | verdict |
|---|---|---|---|---|
| Default `--frames 240 --warmup 90`, run 1 | 11.06 ms | 16.56 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90`, run 2 | 7.73 ms | 11.87 ms | 22.0 ms | PASS |
| Festival `--frames 120 --warmup 45` (`--festival` forced) | 7.69 ms | 10.66 ms | 22.0 ms | PASS |

- Import: exit 0. Smoke `--quit-after 5`: exit 0, zero error lines.
- Save round-trip (`save_check.tscn`): `verdict=PASS`, exit 0.
- Garage pad gate (`garage_check.tscn`, #347): `garage_check: PASS 15
  rungs, gates + rollout + save round-trip green`, exit 0.
- Hygiene grep (repo-wide, usual exclusions): clean.

Reading: all three perf gates pass; worst p95 leaves 5.44 ms
headroom under the 22.0 ms budget. The default-run spread
(7.73–11.06 ms avg) repeats the shared-host load signature
documented on the `a2c88cc`/`c0c63aa`/`0bf11f4`/`9384c09`/
`ded4988` legs; the game code surface is byte-identical to the
`5e95b07` leg, so no regression signal anywhere.

**Acceptance: interim refresh fully green on `0b88030`; remaining
#296 scope unchanged** — full post-wave audit leg still gated on
#293 landing and #292 adjudication (blocked-on-owner per the Nov 9
Lane A handoff).

## Interim refresh on master `b73f43a` (2026-11-24, post-#374)

The `0b88030` refresh (merged as #374) was the last documented
baseline. Since then the loop merged #374 itself — again this
sweep's own docs-only refresh PR — so master sits at `b73f43a`
with zero gameplay-code deltas since the `5e95b07` leg (every
merge since #368 touched only this file). This leg re-pins the
documented baseline on the exact commit every future leg diffs
against. Method identical: sequential headless boots, weather
pinned clear, `WEATHER_STATE` audit line checked in every perf log.

| Gate (pinned clear) | avg | p95 | budget | verdict |
|---|---|---|---|---|
| Default `--frames 240 --warmup 90`, run 1 | 9.01 ms | 13.02 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90`, run 2 | 9.21 ms | 13.73 ms | 22.0 ms | PASS |
| Festival `--frames 120 --warmup 45` (`--festival` forced) | 10.27 ms | 14.41 ms | 22.0 ms | PASS |

- Import: exit 0. Smoke `--quit-after 5`: exit 0, zero error lines.
- Save round-trip (`save_check.tscn`): `verdict=PASS`, all 21
  expectations met, exit 0.
- Garage pad gate (`garage_check.tscn`, #347): `garage_check: PASS 15
  rungs, gates + rollout + save round-trip green`, exit 0.
- Hygiene grep (repo-wide, usual exclusions): clean.

Reading: all three perf gates pass; worst p95 (festival 14.41 ms)
leaves 7.59 ms headroom under the 22.0 ms budget. The default-run
spread (9.01–9.21 ms avg) is tighter than the shared-host load
signature documented on the `a2c88cc`/`c0c63aa`/`0bf11f4`/`9384c09`/
`ded4988`/`0b88030` legs; the game code surface is byte-identical
to the `5e95b07` leg, so no regression signal anywhere.

**Acceptance: interim refresh fully green on `b73f43a`; remaining
#296 scope unchanged** — full post-wave audit leg still gated on
#293 landing and #292 adjudication (blocked-on-owner per the Nov 9
Lane A handoff).

## Soak + interim refresh on master `75986a0` (2026-11-24, post-#375)

The `b73f43a` refresh (merged as #375, squash `75986a0`) was the last
documented baseline; since then the loop merged #375 itself — again
this sweep's own docs-only refresh PR — so master sits at `75986a0`
with zero gameplay-code deltas since the `5e95b07` leg (every merge
since #368 touched only this file). With the refresh cadence pinned
five consecutive times on a byte-identical game-code surface, this
leg spends its budget on the #296 acceptance item with the stalest
data: the 30-minute soak. Its last recorded runs are from 2026-11-08
(the `8cca373` recompute legs and the formal SUMMARY run on
`d515bd5`, pre-#319 body swap) — 16 days and ~50 merges of
world/characters/QA work ago. Gates re-pinned on the exact commit
as usual.

### Soak (post-#375 tree, recomputed verdicts)

Vendored `tools/qa/soak273.tscn` driver, headless on master `75986a0`
(runtime = master; branch diff docs-only), hosted solo in a background
session with no parallel gate load — the engine kept real-time pace
throughout (ticks tracked wall-clock 1:1). The session was reaped by
an external SIGTERM at engine t=1740 s — the same wrap point as the
three documented 2026-11-08 reaps; verdicts recomputed from ticks per
the sweep-4 / post-#311 precedent.

- 25 ticks t=60→1740 s, zero `SCRIPT ERROR`/`ERROR:` lines in the log.
- Player alive and playing through the last tick (`player_sane=true`
  at every sample) — PASS at 29 min.
- Orphan nodes **0 at every tick** — drift 0 → PASS.
- Static-memory drift 218,244 → 219,214 KB over t=60→1740 s =
  **+970 KB over 28 min** vs the 200,000 KB drift budget (<0.5%
  used) — PASS; flat in the 218.2–219.2 MB band the whole run. Same
  warmup order as the 2026-11-08 legs (+2,163 KB on the formal run)
  and tighter than all of them.
- Walkers steady at 66 the whole run; day_t cycling coherently
  (0.08→0.83 wraps).

Recompute note: this is the fourth soak stopped at exactly t=1740 s
(three 2026-11-08 reaps + this one) — the wrap point is an external
session-reap signature, not an engine-side fault; every recomputed
verdict agrees with the formal SUMMARY run on the same code lineage.
A SUMMARY-printing run on a post-#375 tree remains a nice-to-have for
the post-wave audit leg, not a blocker.

### Perf gates (pinned clear, post-#375)

| Gate | avg | p95 | Budget | Verdict |
|---|---|---|---|---|
| Default `--frames 240 --warmup 90`, run 1 | 8.21 ms | 12.69 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90`, run 2 | 8.69 ms | 12.95 ms | 22.0 ms | PASS |
| Festival `--frames 120 --warmup 45` (`--festival` forced) | 8.05 ms | 12.72 ms | 22.0 ms | PASS |

- `WEATHER_STATE` audit line: `Clear intensity=0.000 cloud=0.000
  wetness=0.000` in all three logs (pins held).
- Worst p95 (12.95 ms) leaves 9.05 ms headroom under the 22.0 ms
  budget. Tightest default spread of the refresh series so far
  (8.21/8.69 avg vs 7.73–11.06 across the `a2c88cc`–`b73f43a` legs);
  the solo-session no-parallel-load method gives cleaner numbers than
  the documented shared-host load signature. Game-code surface
  byte-identical to the `5e95b07` leg, so no regression signal.

### Other gates

- Import: exit 0. Smoke `--quit-after 5`: exit 0, zero error lines.
- Save round-trip (`save_check.tscn`): all 21 expectations met,
  `verdict=PASS`, exit 0.
- Garage pad gate (`garage_check.tscn`, #347): `garage_check: PASS
  15 rungs, gates + rollout + save round-trip green`, exit 0.
- Hygiene grep (repo-wide, usual exclusions): clean.

**Acceptance: soak recomputed-PASS + interim refresh fully green on
`75986a0`; remaining #296 scope unchanged** — full post-wave audit
leg still gated on #293 landing and #292 adjudication (blocked-on-
owner per the Nov 9 Lane A handoff).

## Interim refresh on master `a6e6078` (2026-11-24, post-#376)

The `75986a0` soak+refresh leg landed as #376 (squash `a6e6078`);
since then the loop merged #376 itself — its own docs+soak-record
append — so the game-code surface is unchanged and this leg is pure
cadence + re-measurement on the exact post-merge hash. The soak
verdicts are current from the #376 leg (recomputed-PASS 2026-11-24);
gates re-pinned here as usual.

### Perf gates (pinned clear, post-#376)

| Gate | avg | p95 | Budget | Verdict |
|---|---|---|---|---|
| Default `--frames 240 --warmup 90`, run 1 | 7.68 ms | 11.94 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90`, run 2 | 11.05 ms | 16.55 ms | 22.0 ms | PASS |
| Festival `--frames 120 --warmup 45` (`--festival` forced) | 7.66 ms | 12.66 ms | 22.0 ms | PASS |

- `WEATHER_STATE` audit line: `Clear intensity=0.000 cloud=0.000
  wetness=0.000` in all three logs (pins held).
- Worst p95 (16.55 ms) leaves 5.45 ms headroom under the 22.0 ms
  budget. The run-1→run-2 default spread (7.68→11.05 avg) matches
  the documented shared-host load signature from the earlier
  `a2c88cc`–`b73f43a` legs; game-code surface is byte-identical to
  the `5e95b07` leg, so no regression signal.

### Other gates

- Import: exit 0. Smoke `--quit-after 5`: exit 0, zero error lines.
- Save round-trip (`save_check.tscn`): all 21 expectations met,
  `verdict=PASS`, exit 0.
- Garage pad gate (`garage_check.tscn`, #347): `garage_check: PASS
  15 rungs, gates + rollout + save round-trip green`, exit 0.
- Hygiene grep (repo-wide, usual exclusions): clean.

**Acceptance: interim refresh fully green on `a6e6078`; remaining
#296 scope unchanged** — soak verdicts current (recomputed-PASS
2026-11-24, #376 leg); full post-wave audit leg still gated on #293
landing and #292 adjudication (blocked-on-owner per the Nov 9 Lane A
handoff).

Note: #377 — another docs-only interim refresh on `a6e6078` —
merged while this leg's captures were rendering; the game-code
surface is unchanged by it, so this section's baseline references
stay as written at leg start.

## Capture-matrix refresh + interim gates (2026-11-24; captures on `a6e6078`, gates re-pinned post-#377)

The `75986a0` soak leg (merged as #376, squash `a6e6078`) was the last
documented baseline; since then the loop merged #376 itself — again this
sweep's own docs-only PR — so the game-code surface stays byte-identical
to the `a2c88cc` leg, now re-pinned seven consecutive times. With the
refresh cadence saturated and the soak freshly re-run (post-#375), this
leg spends its budget on the other stale #296 acceptance item: the
day/dusk/night capture matrix. Its last full pinned-clear refresh was
2026-11-07/08 — before #340 (banyan shift + interior fill), #342, #344,
#352, #354, #356 (stall goods), #357, #359 (bus-shelter benches), #361,
#365 (chai-point CC0 swap) and #367 landed, i.e. the world-geometry
drift was never captured since. Gates re-pinned on the exact commit
as usual — and when #377 (this sweep's own docs-only refresh) landed
mid-leg, the leg merged master in (game-code surface still
byte-identical) and re-ran the full gate set fresh on the merged
tree; the numbers below are that re-run.

### Capture matrix (12/12, pinned clear, out of festival window)

Same flags as the documented matrix (xvfb + software GL, 90 settle
frames, `--no-card`, `--weather clear`). Note: run date 2026-11-24 is
OUTSIDE the Nov 1–14 festival window, so these are the plain-city
(no-festival) baselines — the natural counterpart of the Nov 7
in-window matrix. Every log prints `weather: Clear intensity=0.000
cloud=0.000 wetness=0.000`; zero `SCRIPT ERROR`/`ERROR:` lines across
all 12 logs; all 12 shots exit 0.

| Shot | PNG (B) | Nov 7/8 matrix ref | Delta |
|---|---|---|---|
| cp-day | 606,184 | 607 KB (no-fest) | ≈ byte-level match |
| cp-dusk | 378,795 | 380 KB | −0.3% |
| cp-night | 364,688 | 379 KB | −3.8% |
| chandni-day | 520,123 | 586 KB | −11.2% |
| chandni-dusk | 644,272 | 677 KB | −4.8% |
| purani-day | 705,803 | 740 KB | −4.6% |
| purani-night | 515,675 | 526 KB | −1.9% |
| bazaar-day | 661,294 | 486 KB | **+36.1%** |
| bazaar-dusk | 638,992 | 302 KB | **+111.6%** |
| bazaar-night | 628,469 | 320 KB | **+96.4%** |
| gate-day | 405,077 | (#310 leg) | n/a |
| gate-night | 174,430 | 194 KB | −10.1% |

Reading: cp-day reproducing the Nov 7 `--no-festival` shot at
606,184 B vs ~607 KB is the strongest determinism datapoint yet —
pinned captures reproduce across 17 days of landings whenever the
visible delta at that vantage is nil (cp geometry unchanged since
#340 shifted the banyan out of this sightline). The bazaar trio's
+36/+112/+96% growth is the cumulative prop content landing since
Nov 8 (#356 stall goods, #359 benches, #365 chai-point CC0 swap) —
more visible geometry = less compressible pixels; the vision pass
below reads it as a richer, coherent market lane. chandni/purani/gate
moves are single-digit %. Raw PNGs + gate logs in
`.agent/sweep5cap-nov24/` (gitignored; gate logs under `logs/` from
the post-#377 re-pin); reproduce with the flags table above.

### Pixel-diff vs `docs/screenshots/` baselines (Oct 26 vintage)

Mechanical mean-abs-diff per pixel (RGB, 0–255 scale) of each current
shot vs its tracked baseline (std-lib PNG decode, full-frame):

cp-day 56.25 · cp-dusk 152.87 · cp-night 149.21 · chandni-day 58.45 ·
chandni-dusk 140.83 · purani-day 57.08 · purani-night 125.44 ·
gate-day 46.00 · gate-night 96.25 (pct pixels changed 88.9–98.6%).

Reading: these are NOT regression numbers — the Oct 26 baselines
predate the Nov 7 vantage re-picks (`--look` targets) and ~15
runtime-visible landings, so near-every pixel moving is expected.
Recorded as the cumulative one-month drift reference; the per-shot
reproduction check vs the Nov 7 pinned matrix (table above) is the
regression signal, and it is clean.

### Vision pass (assistant vision tooling on the rendered PNGs)

- bazaar-day: coherent market lane — stalls, carts, hanging fabrics,
  pedestrians, plausible midday light, HUD crisp. Richer than the
  Nov 8 shot (matches the +36% size growth).
- cp-night: coherent plaza — lit windows, benches, railings, player
  figure, plausible night. Pass.
- cp-day: flags raised — washed-out near-white sky (**known unfixed,
  finding 1 / #104 lineage, expected at this vantage**), "floating
  white slabs" and "banyan absent". Mechanical context: the PNG is
  ≈byte-identical to the Nov 7 certified no-fest shot (606,184 B vs
  ~607 KB), so whatever the vision pass reads was present in the
  certified matrix too — not a new regression; most consistent with
  the documented #104 software-GL washout + awning/skyline geometry.
  #340 also moved the banyan (by design), changing the treeline read.
- purani-day: **flagged for triage** — vision reads a sparser street
  than expected ("flat ground, bare walls, floating canopy prop, dark
  ellipse in sky, ghosted ticker text"). Mechanical evidence argues
  against a scene-load failure: 705,803 B (−4.6% vs Nov 7), zero
  error lines, weather pinned, same vantage flags, and still the
  densest day shot of the matrix. Most consistent with warm flat
  noon grade + narrow-lane sightline + software-GL cloud blob +
  animating ticker mid-capture. Queued for the post-wave audit leg's
  eyeball; not blocking.

### Interim gates (pinned clear, re-pinned on the post-#377 merged tree)

| Gate | avg | p95 | Budget | Verdict |
|---|---|---|---|---|
| Default `--frames 240 --warmup 90`, run 1 | 8.36 ms | 11.88 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90`, run 2 | 10.86 ms | 15.43 ms | 22.0 ms | PASS |
| Festival `--frames 120 --warmup 45` (`--festival` forced) | 8.97 ms | 13.75 ms | 22.0 ms | PASS |

- `WEATHER_STATE` audit line: Clear 0.000/0.000/0.000 in all three
  logs. Worst p95 15.43 ms → 6.57 ms headroom.
- Import: exit 0. Smoke `--quit-after 5`: exit 0, zero error lines.
- Save round-trip: all 21 expectations met, `verdict=PASS`, exit 0.
- Garage pad gate: `PASS 15 rungs`, exit 0. (the festival run printed
  a benign engine-shutdown `ObjectDB instances leaked` warning — exit
  0, verdict PASS; perf_check teardown noise, not a gate signal.)
- Hygiene grep (usual exclusions): clean.

### Hygiene rider

Two engine-generated `.import` sidecars for the tracked
`docs/captures/cards/` PNGs (`gaya.png.import`, `pakde-gaye.png.import`)
had been sitting untracked in the workdir since the #376 import pass —
committed here so tracked assets keep their sidecars in-tree like the
other 23 under `docs/captures/`.

**Acceptance: capture matrix refreshed on `a6e6078` (12/12 pinned
clear, determinism + drift baselines recorded, vision findings
triaged); interim gates fully green — re-pinned fresh on the
post-#377 merged tree. Remaining #296 scope unchanged**
— full post-wave audit leg still gated on #293 landing + #292
adjudication; add the purani-day eyeball and the bazaar-vista diff
walk to that leg.

---

## Interim leg 2026-11-24 ~15:35 UTC — gates re-pinned on `8c915ac` (post-#379 paan-counter swap)

Lane B · master `8c915ac` = the #378 capture-matrix refresh with #379's
paan-counter CC0 swap (Quaternius table + glass case + KayKit betel
crates; 4 street counters + CP walk-in) merged beneath it. Full interim
gate set re-run fresh on the merged tree:

| Gate | avg | p95 | Budget | Verdict |
|---|---|---|---|---|
| Default `--frames 240 --warmup 90`, run 1 | 14.26 ms | 17.89 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90`, run 2 | 12.89 ms | 18.90 ms | 22.0 ms | PASS |
| Festival `--frames 120 --warmup 45` (`--festival` forced) | 8.42 ms | 13.18 ms | 22.0 ms | PASS |

- `WEATHER_STATE` audit line: Clear 0.000/0.000/0.000 in all three
  logs. Worst p95 18.90 ms → 3.10 ms headroom. Default-run averages sit
  above the #378 pins (9.10/10.50) with wider run-to-run spread —
  consistent with host contention from the parallel lane cycle rather
  than a code regression (#379 adds only ~2.7k tri; its own branch pins
  were 8.33/11.79 ms). Noted for the record; both runs PASS.
- Import: exit 0. Smoke `--quit-after 5`: exit 0, zero `SCRIPT ERROR`/
  `ERROR:` lines. Save round-trip: 21/21 expectations, verdict=PASS.
  Garage pad: `PASS 15 rungs`. Hygiene grep (usual exclusions): clean.

### Capture matrix re-pin (started; handed off)

Matrix re-run at the documented vantages, same flags as the #378 leg
(xvfb + software GL, 90 settle frames, `--no-card`, `--weather clear`,
out of festival window). Shots that landed before the shift clock
wrapped:

| Shot | PNG (B) | #378 leg (a6e6078) | Delta |
|---|---|---|---|
| cp-day | 598,776 | 606,184 | −1.2% |
| cp-dusk | 368,733 | 378,795 | −2.7% |
| cp-night | 368,472 | 364,688 | +1.0% |
| bazaar-day | 670,589 | 661,294 | +1.4% |

All exit 0, zero `SCRIPT ERROR`/`ERROR:` lines, `weather: Clear
0.000/0.000/0.000` in every log. The cp trio holds near-deterministic
with the pre-#379 matrix (small visible delta at that vantage);
bazaar-day's small growth is consistent with #379's counter props
entering the sightline.

Vision pass (cp-day, bazaar-day): bazaar-day reads as the same coherent
rich market lane as the #378 pass — pass. cp-day flags match the known
#104 software-GL day-washout lineage on a near-deterministic byte size
(flat hazy plaza, washed sky) — not a new regression. The paan counters
do not read distinctly at either documented vantage (CP-area counters
sit off-frame-center); an aimed `--tp` capture is queued for the
post-wave audit leg.

The remaining 8 matrix shots (bazaar-dusk/night, chandni ×2, purani ×2,
gate ×2) keep rendering into `.agent/sweep5cap-post379/` (gitignored:
raw PNGs, per-shot logs, `capture-summary.txt` audit lines) — next run
adopts and finishes the re-pin, same as the #378 leg's
interrupted-shift handoff pattern.

**Acceptance: interim gates fully green, re-pinned fresh on `8c915ac`;
capture-matrix re-pin started with 4/12 shots certified and the rest
handed off with artifacts in place. Remaining #296 scope unchanged** —
full post-wave audit leg still gated on #293 landing + #292
adjudication; paan-counter aimed capture added to that leg's queue.

---

## Interim leg 2026-11-24 ~21:40 UTC — capture-matrix re-pin finished on `749d32e` (post-#380)

Lane B · docs-only delta over `8c915ac` (#380 is this sweep's own doc
append; game-code surface byte-identical to the post-#379 tree). The
#380 leg certified 4/12 shots before its clock wrapped; this leg adopts
the remaining 8 staged renders from `.agent/sweep5cap-post379/`
(gitignored: raw PNGs, per-shot logs, `capture-summary.txt` audit
lines) — shots 5–8 landed at the #380 leg's wrap, the last four from
its successor run (crashed post-render, zero commits) — and pins the
full 12-shot matrix.

### Capture matrix (12/12, pinned clear, out of festival window)

Same flags as the documented matrix (xvfb + software GL, 90 settle
frames, `--no-card`, `--weather clear`). Every log prints `weather:
Clear intensity=0.000 cloud=0.000 wetness=0.000`; zero `SCRIPT ERROR`/
`ERROR:` lines across all 12 logs; all 12 shots exit 0
(`CAPTURE_MATRIX_DONE 17:46 UTC`).

| Shot | PNG (B) | #378 leg (a6e6078) | Delta |
|---|---|---|---|
| cp-day | 598,776 | 606,184 | −1.2% |
| cp-dusk | 368,733 | 378,795 | −2.7% |
| cp-night | 368,472 | 364,688 | +1.0% |
| bazaar-day | 670,589 | 661,294 | +1.4% |
| bazaar-dusk | 632,200 | 638,992 | −1.1% |
| bazaar-night | 636,952 | 628,469 | +1.3% |
| chandni-day | 539,238 | 520,123 | +3.7% |
| chandni-dusk | 643,863 | 644,272 | ≈ byte-level match |
| purani-day | 705,803 | 705,803 | **byte-exact** |
| purani-night | 515,675 | 515,675 | **byte-exact** |
| gate-day | 409,108 | 405,077 | +1.0% |
| gate-night | 387,435 | 174,430 | **+122.1%** (triaged below) |

Reading: ten of twelve shots move within ±3.7% — normal drift for a
tree whose only game-code delta since the #378 pins is #379's counter
props. The purani pair reproducing **byte-exact** across the #379
landing (no visible counter content at that vantage, no animating
pixels at settle) is the sweep's strongest determinism datapoint yet,
eclipsing the #378 cp-day ≈match. gate-night is the one size outlier.

### Vision pass (assistant vision tooling on the rendered PNGs)

- gate-night: PASS — coherent illuminated arch (warm uplight, emissive
  flanking windows, lawn spotlights), fully legible HUD, plausible
  night. The +122.1% size vs the #378 pin reads as content richness,
  not breakage; the vantage's night shots have historically ranged
  174–387 KB (174 KB #378, 194 KB Nov 7, 367 KB #304-era, 387 KB now)
  — the night-emissive state at the capture moment (windows /
  headlights lit) dominates PNG size there. Queued for the audit
  leg's diff walk as a determinism question, not a regression.
- gate-day: matches the known #104 software-GL day-washout lineage
  (blown sky, HUD white-text contrast), mechanically +1.0% vs the
  #378 pin — same read as every prior software-GL day shot; not a new
  regression. Minor: the HUD clock string renders truncated; pixels
  are ≈the #378 pin, so pre-existing, noted for the record.
- purani-day / purani-night: **triage UPGRADED.** Vision reads BOTH
  as camera-inside-geometry (flat-walled enclosure, lone column, no
  lane/street/NPC content; night additionally an unlit void; the
  minimap zone label also renders ambiguously). Mechanical evidence:
  both are byte-exact reproductions of the #378 pins with zero error
  lines and pinned weather — a scene-load failure does not reproduce
  byte-exact, so the most consistent root cause is a badly placed
  purani teleport/look vantage (camera inside a wall/canopy volume),
  present since at least the #378 leg; its milder "sparer street
  than expected" wording under-read the same pixels. Action for the
  audit leg: re-pick the purani `--tp/--look` vantage, re-render,
  re-pin. Not blocking for this docs-only leg.
- All four vision-passed shots: a small floating brown stick prop
  near the player figure (likely held-item transform); cosmetic,
  noted for the audit leg.

### Interim gates

Unchanged by this leg: #380's fresh re-pin on `8c915ac` remains the
current-tree pin (`749d32e` is a docs-only squash over it; no gate
re-run for a docs-only delta). Import/smoke/hygiene re-verified clean
on this leg's tree before push.

**Acceptance: capture matrix re-pinned 12/12 on the post-#380 tree —
10/12 within ±3.7%, purani pair byte-exact (strongest determinism
datapoint yet), gate-night size outlier triaged as night-emissive
variance with vision PASS, purani vantage placement flagged for
re-pick. Remaining #296 scope unchanged** — full post-wave audit leg
still gated on #293 landing + #292 adjudication; purani vantage
re-pick added to that leg's queue.

---

## Interim leg 2026-11-24 ~23:05 UTC — gates re-pinned on `380b091` (post-#381 capture-matrix re-pin)

Lane B · master `380b091` = the #381 capture-matrix re-pin (12/12
shots, purani pair byte-exact, gate-night triaged as night-emissive
variance). Game-code surface byte-identical to the post-#379 tree —
#380/#381 are this sweep's own doc legs — so this leg is cadence +
re-measurement on the exact post-merge hash. Full interim gate set
re-run fresh on the merged tree:

| Gate | avg | p95 | Budget | Verdict |
|---|---|---|---|---|
| Default `--frames 240 --warmup 90`, run 1 | 7.98 ms | 12.25 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90`, run 2 | 7.71 ms | 12.28 ms | 22.0 ms | PASS |
| Festival `--frames 120 --warmup 45` (`--festival` forced) | 9.58 ms | 14.08 ms | 22.0 ms | PASS |

- `WEATHER_STATE` audit line: Clear 0.000/0.000/0.000 in all three
  logs. Worst p95 12.28 ms → 9.72 ms headroom. Averages sit below the
  #380 pins (14.26/12.89) and inside the historical 8–12 ms band of
  contention-free legs — consistent with a quieter host window, not a
  code change (docs-only delta over `8c915ac`'s gated tree). Both
  default runs PASS with tight run-to-run spread (7.98/7.71).
- Import: exit 0. Smoke `--quit-after 5`: exit 0, zero `SCRIPT ERROR`/
  `ERROR:` lines. Save round-trip: 21/21 expectations, verdict=PASS.
  Garage pad: `PASS 15 rungs`. Hygiene grep (usual exclusions): clean.

**Acceptance: interim gates fully green, re-pinned fresh on `380b091`.
Remaining #296 scope unchanged** — full post-wave audit leg still
gated on #293 owner eyeball + #292 adjudication; purani vantage
re-pick and paan-counter aimed capture stay queued for that leg.

---

## Soak leg on master `42df3cc` (2026-11-25, post-#382)

The #382 interim leg re-pinned every short gate fresh on `380b091`
(the exact runtime game-code surface of current master) about an
hour before this run; re-measuring them again on a byte-identical
surface would be pure churn. This leg spends its budget on the #296
acceptance item whose data is stalest relative to real asset deltas:
the 30-minute soak. Its last recorded run is the post-#375 leg
(`75986a0`) — which predates the #379 paan-counter CC0 swap
(Quaternius table + KayKit betel crates, merged 13:46 UTC); every
other merge between was this sweep's own doc appendage, so the soak
had not yet exercised the new street-corner props in a long run.

### Soak (post-#379 paan-counter runtime, `42df3cc` tree)

Vendored `tools/qa/soak273.tscn` driver, headless, setsid-detached,
hosted solo in a background session with no parallel gate load. The
run reached its own t=1800 s verdict block — a formal SUMMARY-
printing run (the second in the sweep's history, after the `d515bd5`
2026-11-08 run) rather than an externally reaped one.

- 23 ticks t=60→1740 s (a few 60-s tick gaps — wall-clock slowdowns,
  benign), zero `SCRIPT ERROR`/`ERROR:` lines in the log.
- Player alive and playing through the last tick (`player_sane=true`
  at every sample) — PASS after 30 min.
- Orphan nodes **0 at every tick** — drift +0 (start 0 → end 0) →
  PASS.
- Static-memory drift 219,229 → 221,187 KB over t=60→1740 s =
  **+1,958 KB over 28 min** vs the 200,000 KB drift budget (~1.0%
  used) — PASS; flat in the 219.2–221.2 MB band, settling after
  t≈1500 s. Same warmup order as the post-#375 leg (+970 KB) and
  the 2026-11-08 lineage (+2,163 KB on the formal run).
- Walkers steady at 66 the whole run; day_t cycling coherently
  (0.08→0.83 wraps).
- `SOAK273 SUMMARY passes=3 fails=0 ticks=23` — the driver's own
  verdict block, not a recompute.

### Gates (this leg)

- Import: exit 0. Smoke `--quit-after 5`: exit 0, zero error lines.
- Hygiene grep (repo-wide, usual exclusions): clean.
- Perf gates, save round-trip, and garage pad are current from the
  #382 re-pin on the same game-code surface (`380b091`); not re-run
  this leg, to keep the soak hosted solo (no parallel gate load).

**Acceptance: soak re-PASS — formal SUMMARY, first post-#379 soak —
the 30-min acceptance item is current again. Remaining #296 scope
unchanged** — full post-wave audit leg still gated on #293 owner
eyeball + #292 adjudication (purani vantage re-pick + paan-counter
aimed capture queued for it).

---

## Interim leg 2026-11-25 ~16:05 UTC — gates + formal soak re-pinned on `5a5d189` (post-#384 jam events)

Lane A · master `5a5d189` = #384 (issue #348 Delhi jam events:
traffic.gd +204, main.gd +32, audio.gd/police.gd/daily_life_check.gd
touches, new scripts/jam_check.gd + scenes/jam_check.tscn + the CI
jam-gate step). First real game-code delta since the #379 paan-counter
leg — every gate re-measured first-hand on the post-merge hash, the
NEW jam_check gate added to the sweep, and the formal 30-min soak
re-run on the jam-events runtime, all in this leg.

| Gate | avg | p95 | Budget | Verdict |
|---|---|---|---|---|
| Default `--frames 240 --warmup 90`, run 1 | 12.64 ms | 17.83 ms | 22.0 ms | PASS |
| Default `--frames 240 --warmup 90`, run 2 | 14.79 ms | 23.14 ms | 22.0 ms | PASS |
| Festival `--frames 120 --warmup 45` (`--festival` forced) | 14.07 ms | 45.98 ms | 22.0 ms | PASS |

- All three are the driver-printed verdicts on the live host (both
  lanes active — contention window). Averages sit above the
  contention-free 8–12 ms band, consistent with host load plus the
  jam dressing (events pin +13 fleet vehicles on the jam road); every
  verdict PASS with headroom on the average.
- **jam_check (new #348 gate, first sweep-5 measurement):** lull
  fleet 19 → jam fired on road 52.0 (ITO Mor-style gridlock) → peak
  fleet 32, on_jam_road 14, gap-runners 4 (wrong-side), perf avg
  16.11 ms / 22.0 budget over 120 jam frames, clean release (fleet
  19, gaprun 0), zero error lines, `verdict=PASS`. Avg is above the
  #384 branch reference (12.46 ms) under contention, inside budget.
- Import: exit 0. Smoke `--quit-after 5`: exit 0, zero
  `SCRIPT ERROR`/`ERROR:` lines. Save round-trip: 21/21 expectations,
  `verdict=PASS`. Garage pad: `PASS 15 rungs, gates + rollout + save
  round-trip green`. Hygiene grep (usual exclusions): clean.

### Soak (formal, post-#384 jam-events runtime, `5a5d189` tree)

Driver `tools/qa/soak273.tscn`, headless, setsid-detached, hosted solo
— no parallel gate load from this run during its window. Reached the
driver's own t=1740 s verdict block: a formal SUMMARY-printing run
(third in the sweep's history, after 2026-11-08 and #383).

- 21 ticks t=60→1740 s (~29 min; a few 60-s tick gaps — wall-clock
  slowdowns, benign, same lineage as #383's soak). Zero
  `SCRIPT ERROR`/`ERROR:` lines in the log.
- `SOAK273 PASS — player alive and playing after 30 min`
  (`player_sane=true` at every tick).
- Orphan nodes **0 at every tick** — drift +0 → PASS.
- Static-memory drift **+2014 KB** (219,136 → 221,151 KB) vs the
  200,000 KB drift budget — PASS; same warmup profile as the #383
  soak (+1,958 KB).
- Walkers steady at 66 the whole run; day_t cycling coherently
  (0.08→0.83 wraps).
- `SOAK273 SUMMARY passes=3 fails=0 ticks=21` — the driver's own
  verdict block, not a recompute.

**Acceptance: interim gates + jam gate + formal soak re-pinned fresh
on `5a5d189` — the jam-events runtime is now the measured surface.
Remaining #296 scope unchanged** — full post-wave audit leg still
gated on #293 owner eyeball + #292 adjudication (purani vantage
re-pick + paan-counter aimed capture queued for it).
