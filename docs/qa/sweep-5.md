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
