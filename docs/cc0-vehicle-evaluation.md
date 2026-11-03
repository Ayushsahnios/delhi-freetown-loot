# CC0 vehicle body evaluation — issue #294

Research-first evaluation (MODEL SWAP 4): can a genuine CC0 modeled
vehicle beat the current lofted hulls on screen? Verdict and next steps
below. No code or scene changes in this document's PR.

## What the fleet is today

Seven procedural bodies (rickshaw, hatchback, van, scooter, tempo,
truck, tanker) built from chamfered lofts since the #237 de-box wave,
with the #166 matte/gloss finish split, drivers, decor and per-kind
exhaust. One geometry source feeds both the drivable vehicle and the
merged-mesh traffic fleet, which is what keeps the whole street within
the perf budget (one surface per color, MultiMesh draws).

## Candidates checked (2026-11-03)

| Source | License | Reachable this run | Fit |
|---|---|---|---|
| Kenney car kit | CC0 (toon low-poly) | site refused automated fetch (HTTP 403) — canonical zips could not be pulled to verify contents | NO — rounded toy shapes fight the PS2-era realism art bar and would make the "toy/robot" read worse |
| Quaternius packs | CC0 (toon) | yes | NO — vehicle offerings are tanks / trains / sci-fi; no rickshaw, no street hatchback/van; toon style |
| poly.pizza (CC0 aggregator, hosts tuk-tuk models) | per-model CC0 | no — site and static download host both refused automated fetch (HTTP 403) | UNVERIFIED — cannot download or license-check a single model from the build environment |
| Sketchfab CC0 filter | per-model CC0 | downloads need a logged-in account | UNVERIFIED — has auto-rickshaw candidates, but each model page must be eyeballed for a real CC0 mark (CC-BY mislabeled as CC0 is common there) |

## Verdict

No swap. Everything either downloadable or license-verifiable this run
is a style downgrade (toon vs the owner's realism reference), and the
two plausible sources for a realistic auto-rickshaw could not be
reached or verified from the build environment. Swapping in an
unverified or off-style model would trade the owner's art bar for a
checkbox. The lofted hulls stay until a genuinely better CC0 body is
in hand.

## Recommended next steps (in order)

1. **Owner-curated shortlist** (5 min in a browser): on poly.pizza or
   Sketchfab, filter CC0, pick 2-3 auto-rickshaw + hatchback models,
   confirm the license badge on each page, download the GLBs and drop
   them into a follow-up issue. A code run then wires them in behind a
   bake step (GLB surfaces merged per material, paint recolor kept) so
   the traffic fleet stays one-surface-per-color.
2. **Anti-robot detail pass on the existing hulls** (no license risk,
   cheap): panel seams, door handles, side mirrors, window rubber,
   number plates — the small high-contrast geometry that makes a
   lofted body read manufactured rather than molded. Deferred this
   run; it is the best bang-for-buck if the shortlist stalls.
3. **Any swapped asset ships with docs**: license text + attribution
   under `docs/licenses/`, no brand liveries, per the MODEL SWAP rule.

## Gates

Docs-only change: vehicle_check, night/street captures and the perf
gate are untouched and expected green; they run in CI as usual.
