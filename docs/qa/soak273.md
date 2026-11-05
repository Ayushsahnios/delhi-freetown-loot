# soak273 — 30-minute headless long-run soak driver

Vendored QA driver (`tools/qa/soak273.gd` + `soak273.tscn`) for the
issue #273 / #296 lineage: boots the real game headless, starts the
first legend, then lets the full sim run for 30 minutes while hopping
between landmarks every 2 minutes (exercises LOD wake/sleep, crowd
zones, traffic, day cycle). Every 60 s it samples orphan-node count,
static memory, walker count, and player sanity, then prints verdict
lines. This is the long-run companion to the per-sweep docs
(`sweep-1/2/4/5.md`); sweep 5 (issue #296) re-runs it after the model
swap wave lands.

## Run it

From the repo root with a Godot 4.x binary:

```
godot --headless tools/qa/soak273.tscn 2>&1 | tee /tmp/soak273.log
```

Exit code `0` = all verdicts passed, `7` = at least one FAIL line.
Full run is 30 min; plan CI around the short gates, not this driver.

## Verdicts

| Verdict | Budget | Meaning |
|---|---|---|
| player alive and playing | still playing at 30 min | sim did not wedge |
| orphan-node drift | < 2000 over the soak | no node leak |
| static-memory drift | < 200,000 KB (~195 MB) over the soak | no heap creep |

## Units note (v1.1 fix)

`Performance.MEMORY_STATIC` reports **bytes**. The pre-vendored
prototype printed raw bytes labelled `mem_kb` and thresholded the raw
byte delta against a KB budget, so a benign ~+1.8 MB drift over 30 min
printed as `+1872748 KB` and false-FAILED. v1.1 converts bytes → KB at
both the tick print and the drift verdict, so ticks now read
`mem_kb=193958` (~189 MB) and the same baseline drift reads
`+1828 KB` against the 200,000 KB budget — a clear PASS.

## Baseline numbers (2026-10-31 run, pre-model-swap master)

- 22 ticks over 30 min, game booted, first legend started
- orphans 0 → 0 (PASS), player alive and playing at 30 min (PASS)
- static memory ~189 MB flat; drift +1,872,748 bytes = **+1828 KB**
  over 30 min — well inside budget (the logged FAIL was the units bug
  above, not a leak; exit code 7 on that run came from the same bug)
- walker count steady at 66 across the whole soak

A fresh full soak against post-swap master is part of gated sweep 5.
