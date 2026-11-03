# Asset licenses

Every external asset shipped in this repository is listed here with its
license and provenance. Anything not in this table is original work
generated procedurally by this project's own code.

| Asset | Folder | License | Source |
|---|---|---|---|
| Rigged pedestrian meshes (`male_rigged.glb`, `female_a.glb` … `female_d.glb`) | `assets/characters/` | CC0 1.0 Universal | "Animated Men" / "Animated Women" packs (Feb 2019) by Quaternius |
| Noto Sans Devanagari Bold (UI font) | `assets/fonts/` | SIL Open Font License 1.1 | Google Fonts |

## Policy

- External assets must be **CC0 / public domain** (fonts: SIL OFL).
  No Mixamo content, nothing derived from or ripped out of a
  commercial game — genre *mechanics* only, never code, art, audio,
  names or trademarks.
- A license statement must sit **next to the assets it covers**: every
  folder under `assets/` that holds binary assets also holds a
  `LICENSE.txt` (or the upstream `OFL.txt`) quoting the license and the
  source.
- CI enforces the rules above plus a size budget in the
  **Asset license + size gate** step (`scripts/asset_gate.sh`).

## Intake process (how new assets land)

1. **Stage** candidate files in `.agent/assets/` — that folder is
   gitignored on every work machine and must never be committed.
2. **Verify** the license at the source (the author's own site or
   repository), never from a rehost. Record author, pack name, date,
   license and source URL.
3. **Commit** the winners under `assets/<category>/` together with a
   `LICENSE.txt` in that same folder and a new row in the table above.
4. **Gate** — `scripts/asset_gate.sh` runs locally and in CI, so a PR
   that adds an asset without its license file (or over the size
   budget) fails before review.

## Size budget (repo bloat guard)

| Limit | Value |
|---|---|
| Total size of `assets/` | 48 MB |
| Any single asset file | 12 MB |

Raise the budget only with a deliberate PR that says why.
