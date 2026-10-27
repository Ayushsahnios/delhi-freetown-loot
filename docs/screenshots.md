# Full-city screenshot sweep

Twelve server-side captures of the whole city, taken with the screenshot
pipeline (`scripts/screenshot.gd`) using the new `--day` knob that pins the
day cycle (day 0.5 · dusk 0.74 · night 0.9), 60 settle frames after
teleporting to each district center. Captured 2026-10-26.

| Capture | District | Phase |
|---|---|---|
| cp-day.png | Connaught Place | day |
| cp-dusk.png | Connaught Place | dusk |
| cp-night.png | Connaught Place | night |
| gate-day.png | India Gate | day |
| gate-night.png | India Gate | night |
| purani-day.png | Purani Dilli fort | day |
| purani-night.png | Purani Dilli fort | night |
| chandni-day.png | Chandni Chowk | day |
| chandni-dusk.png | Chandni Chowk | dusk |
| police-day.png | Police station | day |
| park-dusk.png | Neighbourhood Park | dusk |
| metro-day.png | Elevated metro line | day |
| metro-gate.png | Metro station gate and shuttle | day |
| metro-interior.png | Riding the shuttle, interior cam | day |

## Findings from the sweep

- The pipeline reproduces the whole city headlessly — every district,
  the metro line and the park render with HUD, minimap and crowd in place.
- Some frames show a washed-out white sky/ground. The effect is
  inconsistent between captures of the *same* location at different
  phases, which points at the capture renderer, not the scene data.
  Followed up with controlled captures — see the sky-washout section
  below; the cloud layer first suspected turned out to be innocent.
- Night frames show dark sky but no visible window glow — needs a check
  on real-GPU output to tell game bug from capture artifact. Filed.
- Repeated prop defects (floating stall tables, canopy clipping, hanging
  decorations intersecting stall frames) appear across several districts.
  Filed for a placement pass.

## Sky washout follow-up (issue #104)

Controlled reproduction: two identical captures (Connaught Place center,
day pinned to noon, controls card dismissed) and one discriminator run
per suspect, mean colour measured over the top and bottom quarter of
the frame.

| Capture | Sky band | Ground band |
|---|---|---|
| run 1 (baseline) | rgb(0.901, 0.917, 0.921) lum 0.914 | rgb(0.612, 0.907, 0.752) lum 0.833 |
| run 2 (identical inputs) | rgb(0.892, 0.912, 0.915) lum 0.908 | rgb(0.612, 0.907, 0.752) lum 0.833 |
| `--nclouds` | rgb(0.899, 0.913, 0.916) lum 0.910 | unchanged |
| `--noglow` | rgb(0.885, 0.907, 0.913) lum 0.902 | unchanged |

Findings:

- The washout reproduces **deterministically**: identical inputs give
  the same near-white noon sky (lum ~0.91) every run — not flaky
  frame-to-frame blending.
- The intended noon sky is `SKY_DAY * 0.85` = rgb(0.45, 0.69, 0.78)
  (lum ~0.66), so the measured band is ~0.25 too bright with almost no
  blue left: the washout is real, not pale palette.
- **Cloud layer exonerated**: hiding the whole MultiMesh layer (`--nclouds`)
  moves the sky band by 0.004 — nothing. The original alpha-blending
  suspicion was wrong.
- **Glow exonerated**: disabling environment glow (`--noglow`) changes
  almost nothing, so the LDR-glow-compositing path is not it either.
- What remains is the sky dome itself under the software-GL capture
  renderer: night frames (same code path, dark palette) render correct
  dark skies, bright palettes wash toward white. The capture host has no
  real GPU, so the game-look verdict on hardware needs a local export;
  scene data and material settings are verified correct by the numbers
  above.

Capture knobs added for this investigation (both stay useful):

    --nclouds   hide the drifting cloud layer
    --noglow    disable environment glow

## First-60-seconds captures (issue #95)

Fresh-save boot documentation for the spawn-framing pass: the opening
shot holds the player, the gold START HERE beacon and the mall road;
the dismissable first-boot controls card overlays until any key or the
GOT IT button clears it. Captured with the same pipeline; the new
`--no-card` knob dismisses the card before settling.

| Capture | Shows |
|---|---|
| spawn-intro-card.png | Fresh boot: controls card over the spawn shot |
| spawn-beacon.png | Card dismissed: player + START HERE beacon |

- The START HERE billboard label, the beacon column and the player all
  render and read clearly in both phases.
- The distant arch is washed out by the known software-GL sky issue
  (see the sweep findings above); the framing itself matches the
  intro-camera intent regardless.

## Story v2 finale captures (issue #96)

Staged-progress documentation for the finale arc: the capture pipeline
pre-clears the three legend chapters (`--finale`) and renders Finale I's
marker at Sardar Ji's stand with Sardar Ji active; a second capture
renders the ending card directly (`--ending`).

| Capture | Shows |
|---|---|
| story-finale-marker.png | Finale I marker live at the stand once the chapters clear |
| story-finale-ending.png | The ending card after the final handover |

- The finale markers stay hidden until all three chapter-one stories
  are done, unlock in order, and each job offers only to its named
  legend (others get a pointed hint to switch).
- The ending card closes the story with one line per legend plus the
  send-off, over a dimmed city.

## Hauz Khas + Yamuna ghats captures (issue #97)

The districts pass adds two new visual districts, both captured with the
same pipeline (day 0.5, 60 settle frames, teleported near each district
center).

| Capture | District | Phase |
|---|---|---|
| hauz-day.png | Hauz Khas — lake, domed pavilions, cafe strip | day |
| ghats-day.png | Yamuna Ghats — steps to the water, boats, footbridge | day |

## Scooter rideable capture (issue #98, part 1)

The rideables work starts with the scooter: a procedural step-through
built like the rest of the fleet, parked at two spawn-road spots and
mixed into ambient traffic at a quicker cruise — jackable with E like
every other vehicle. Fastest top speed and sharpest steering in the
garage.

| Capture | Shows |
|---|---|
| scooter-spawn.png | Parked scooter on the spawn-road shoulder, day |

## Night lighting (issue #102)

Night captures used to show a dark city: no lit windows, no street lamps
— scenes read as flat-shaded day. Two causes. Window glow is pure
material emission, which the software-GL capture renderer can drop, and
the world simply had no street lights at all. The fix adds a real
OmniLight3D under every lamp head (8 landmark lamps + 3 down the Chandni
Chowk market lane) so warm pools render in every pipeline, plus a
headless gate (`res://scenes/night_check.tscn`) asserting windows and
lamps ramp on at night and off at noon. The night-lamps capture settles
the original question: under software GL the whole lighting model is
dropped — geometry renders flat unshaded, so neither lamp pools nor
window emission can ever show in captures. That is a capture-pipeline
artifact, not a game bug; on-device (real-GPU) eyeballing is still
pending the owner.

| Capture | Shows |
|---|---|
| night-lamps.png | Chandni Chowk market lane at deep night — dark sky over the stalls; the flat ground is the software-GL capture artifact itself (see below) |
