# DELHI STORIES — Project Plan (Godot edition)

> GTA–San-Andreas-inspired free-roam game, Delhi-themed, built from scratch.
> Lead developer: OpenClaw agent · Product owner/reviewer: Ayush Sahni
> Plan date: 2026-10-21 · Engine decision: **Godot 4.7, from scratch**

## 1 · Vision & Pillars

- **Free roam first.** The whole city open from minute one; missions optional.
- **Delhi is the character.** India Gate, Connaught Place, Purani Dilli, metro,
  monsoon (later). Warm homage, never parody.
- **Characters you pick.** Jaspreet "Sardar Ji" Singh leads a three-person cast.
- **100% original.** Own engine choice (Godot, MIT), own code, own procedural
  assets. Mechanics may be inspired by the genre; no code/assets/names from any
  commercial game. This project is lawyer-proof by construction.

## 2 · Why Godot 4 (decision record)

| Option | Verdict |
|---|---|
| Reverse-engineer GTA:SA engine | **Rejected — illegal + sued into the ground historically (re3/reVC/SA decomp precedent)** |
| Keep Three.js web build | Kept as the v0.1 web demo; ceiling too low for "full game" systems |
| **Godot 4** | **Chosen** — MIT license, real engine (physics, animation, nav AI, streaming), web/desktop/mobile export, zero ownership risk |

Web export notes: single-threaded export avoids SharedArrayBuffer headers;
any static file host serves it.

## 3 · Architecture

- `project.godot` — config, autoload (`scripts/game.gd`), mobile renderer
- `scenes/main.tscn` — single scene; everything else is procedural
- `scripts/game.gd` — autoload: input map (runtime-defined), character roster
- `scripts/main.gd` — world builder (city grid, landmarks, metro), select UI,
  camera, day/night, vehicle enter/exit
- `scripts/player.gd` — CharacterBody3D player, procedural low-poly humans
  (Sardar turban + beard variants), walk animation
- `scripts/auto.gd` — arcade auto-rickshaw

Content pipeline stays code-generated (BoxMesh/CylinderMesh/SphereMesh).
CC0 asset packs (kenney.nl) allowed from v0.2 for props if wanted.

## 4 · Milestones

- **v0.1-G "Skeleton" (this commit)** — select screen, walkable city, autos,
  day/night, chase cam, HUD. Headless-import verified.
- **v0.2-G "Streets Alive" (week 1)** — traffic AI (NavigationServer3D lanes),
  pedestrians, minimap, horn + ambient audio, mobile touch UI
- **v0.3-G "Wanted" (week 2)** — wanted stars, police AI chase, health, arrest
- **v0.4-G "Paisa" (week 3)** — money, delivery/race missions, street-food
  economy
- **v0.5-G "Kahani" (weeks 4–6)** — three story arcs, dialogue, saves,
  character switching
- **v1.0-G (months 2–3)** — districts (Chandni Chowk, Hauz Khas), monsoon,
  radio, gamepad, polish

## 5 · Process

- Backlog = GitHub issues (`priority:*`, `milestone:vX.Y-G`)
- Branch + PR flow; CI (headless import + export smoke) from v0.2
- Milestone gates: tag + playtest note to owner
- Optional hourly improvement loop (same automation that delivered 28/28 on
  the rulebook project) — armed on owner's word

## 6 · Repo hygiene rules (owner-mandated)

- **No server URLs, no IP addresses, no credentials, no deployment endpoints**
  in this repository — deployment config lives outside the repo.

## 7 · Definition of Done (per feature)

Code complete · `godot --headless --import` clean · export smoke green ·
playable by owner · issue closed with notes.
