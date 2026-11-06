# Human model-swap candidate lineup (issue #291)

In-engine lineup of the four CC0 candidate humans vendored by #299
(Quaternius Modular Men/Women packs, Worker + Casual variants), rendered
under flat day lighting with a 1.70 m reference post. Every figure is
sized by the same basis math as game spawns (`characters.gd`) and shown
in its honest bind pose (strict T-pose — the packs ship unanimated).

## Captures

| File | Subject |
| --- | --- |
| `lineup-wide.png` | all four candidates side by side, front view |
| `portrait-0.png` | Men / Worker — closeup |
| `portrait-1.png` | Women / Worker — closeup |
| `portrait-2.png` | Men / Casual — closeup |
| `portrait-3.png` | Women / Casual — closeup |

## Measured facts (from the capture run's stdout)

| Model | Triangles | Meshes | Bones | Height |
| --- | --- | --- | --- | --- |
| quat_men_Worker | 5,240 | 4 | 49 | 1.70 m (spawn band) |
| quat_women_Worker | 6,084 | 4 | 51 | 1.70 m (spawn band) |
| quat_men_Casual | 6,206 | 4 | 49 | 1.70 m (spawn band) |
| quat_women_Casual | 6,396 | 4 | 51 | 1.70 m (spawn band) |

Per-walker triangle cost drops ~2.6x against the current universal male
base (13,744 tris) while adding modeled outfits (hard hats, hi-vis
vests, hoodies), which is the point of the swap.

Rig facts probed for the Phase-2 swap: the candidates carry the
Quaternius v2 universal rig (`Root/Hips/Abdomen/Torso/Chest/Neck/Head/
Shoulder.L..Foot.R` plus articulated fingers; the women's rig adds
proximal finger bones) and **ship with no embedded animation clips**.
The core chain bone names match the in-tree v1 female rigs
(`female_a`–`d`), so their idle/walk/run clips can be retargeted by
name onto these skeletons (rest-frame conversion required — the limb
rest conventions differ, verified by render probes).

## Owner auto-pick (Option A, 2026-11-04 15:32 UTC, veto anytime)

- **Walkers → Worker pair** (`quat_men_Worker`, `quat_women_Worker`)
- **Legends → Casual pair** (`quat_men_Casual`, `quat_women_Casual`)

## Re-capturing

```bash
godot --headless --import .
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
  --rendering-driver opengl3 res://scenes/human_lineup.tscn \
  -- --out docs/captures/humans/lineup-wide.png --mode wide
# portraits: --mode p0 .. p3
```
