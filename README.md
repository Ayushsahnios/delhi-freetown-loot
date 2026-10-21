# Delhi Stories 🪯🛺 — Godot build

A GTA–San-Andreas-inspired **free-roam game set in Delhi**, built from scratch
on **Godot 4** (MIT-licensed engine). 100% original code and assets — everything
procedural, nothing reverse-engineered, nothing licensed.

## Characters
- **Jaspreet "Sardar Ji" Singh** — auto-rickshaw legend of Connaught Place
- **Riya Sharma** — delivery rider, fastest lanes in the city
- **Monty "Dilli ka Don" Malhotra** — Connaught Place hustler

## Controls
WASD / arrows — move · Shift — run · E — enter/exit vehicle · H — horn (planned)

## Run it
Open this project folder in **Godot 4.7+** and press F5. Or headless:

```bash
godot --headless --import   # verify the project parses
godot --path .              # run
```

Web export (hostable on any static file server):

```bash
godot --headless --export-release "Web" build/index.html
```

## Status
v0.1 skeleton — character select, free-roam city grid (India Gate, CP
roundabout, Purani Dilli, metro line), drivable auto-rickshaws, day/night
cycle, chase camera. Roadmap and process: [PLAN.md](PLAN.md)

## Legal
Original work. Game *mechanics* inspired by the open-world genre; no code,
assets, audio, names, or trademarks from any commercial game are used.
