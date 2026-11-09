# Vehicle body verdict + street capture — issue #294 closeout leg

Owner-approved detail pass (2026-11-04) is fully landed. This doc records the
CC0-vs-lofted verdict and the street capture leg; one night capture remains
(next shift, see handoff).

## Verdict: keep the lofted hulls

The CC0 vehicle evaluation (docs/cc0-vehicle-evaluation.md, PR #297) found no
license-verifiable CC0 auto-rickshaw/car candidate that clears the art bar —
the reachable sets (Kenney, Quaternius) are toon-style downgrades against the
PS2-realism reference. Its recommended fallback — an anti-robot detail pass on
the procedural lofted hulls — is what landed:

- **Part 1a** (PR #311): panel scribes + stub door handles + number plates on
  the street trio (hatchback / van / tempo), `vehicle_check` plate gate added.
- **Part 1b** (PR #327): side mirrors on the trio (24 mirror tris/kind) +
  rickshaw mirror, window rubber rails + windshield-crown strips, mirror gate
  (`vehicle_check` gate 7: every street kind ≥ 24 HUB mirror-blade tris).

Procedural only, existing palette, no new assets — originality mandate intact.

## Gates (all green, post-#327 tree)

- `vehicle_check`: **PASS 7/7** re-run on this branch (wheels, gloss split,
  lamp glow, exhaust, heavy fleet, plates, mirrors). Tri totals: hatch 1124,
  van 1112, tempo 2000, street-trio mirror geometry 24 tris/kind.
- Perf gates (PR #328, pinned clear): default-clear avg 8.49 / p95 12.82 ms,
  festival-clear avg 8.17 / p95 12.62 ms — both PASS vs the 22.0 ms budget.
- Soak (PR #330): third formal SUMMARY-printing run, `passes=3 fails=0`,
  orphan drift +0, static-memory drift +1856 KB (~0.9% of budget).

## Street capture (day)

`docs/screenshots/vehicle-detail-1b-street-day.png` — street vantage on the
road between blocks (4,7)/(5,7) (player at the block-edge road center, block
center math: -253 + ix*46 + 6), pinned noon + clear weather via the sweep-5
capture knobs, festival dressing active:

```
xvfb-run -a godot --path . --rendering-driver opengl3 \
  res://scenes/screenshot.tscn -- \
  --out docs/screenshots/vehicle-detail-1b-street-day.png \
  --tp -40,75 --day 0.5 --weather clear --no-card --frames 120
```

Vision audit: auto-rickshaw center-frame at mid-distance, form readable
(green body, yellow canopy accents, driver silhouette); street trio detail
(mirrors/rubber/plates) is below single-vehicle readability at street
distance — the vehicle_check geometry gates are the per-detail proof, this
capture is the in-world placement/atmosphere proof. Scene healthy: facades,
curbs, power lines, HUD/minimap all render; one cow in shot.

Observation for the sweep-5 notes: pinned noon + clear washes the far field
into fog/bloom under software GL (same family as the #104 glow washout);
future street baselines should pair a `--noglow` variant for contrast.

## Remaining for #294 close

- Night street capture at the same vantage (`--day 0.02 --weather clear`),
  committed beside the day shot, then the issue closes with this doc as the
  verdict record.
