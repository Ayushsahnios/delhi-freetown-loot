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

## Findings from the sweep

- The pipeline reproduces the whole city headlessly — every district,
  the metro line and the park render with HUD, minimap and crowd in place.
- Some frames show a washed-out white sky/ground. The effect is
  inconsistent between captures of the *same* location at different
  phases, which points at the capture renderer (software GL alpha
  blending on the cloud layer), not the scene data. Filed for follow-up.
- Night frames show dark sky but no visible window glow — needs a check
  on real-GPU output to tell game bug from capture artifact. Filed.
- Repeated prop defects (floating stall tables, canopy clipping, hanging
  decorations intersecting stall frames) appear across several districts.
  Filed for a placement pass.
