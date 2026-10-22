# Delhi Freetown Loot 🪯🛺

**An indie free-roam loot game set in Delhi** — GTA–San-Andreas-inspired
open world, built 100% from scratch on [Godot 4](https://godotengine.org)
(MIT-licensed engine). Original code, original procedural assets, nothing
reverse-engineered, nothing licensed.

**v1.0 is out** — read the [release notes](PLAN.md#8--changelog).

## The city
Free-roam a stylized low-poly Delhi from minute one — India Gate, Connaught
Place roundabout, Purani Dilli's red fort and dome, parks, and an elevated
metro line overhead. Day/night cycle, drivable auto-rickshaws, living
traffic and pedestrians, player health with landmark respawns, and a
wanted system — cause chaos and police jeeps hunt you through the grid;
lose them and the heat cools; get cornered while wanted or go down hot
and it's **BUSTED** — fine out of your wallet, respawn outside the thana
police station, heat wiped. Glowing street markers hand out missions
for cash: street tests, a three-stop chai run against a cooling timer,
and a checkpoint ring race against two rival auto-rickshaws. Street thela
carts at every landmark sell chai and samosas — mission cash in, health
back out, the first real money sink. Mission givers talk now: walk into
a glowing marker and a typewriter dialogue box opens — the chai uncle
and rival pullers make their pitch, you take the job or turn them down
to their face. Each legend opens their Kahani with a one-shot intro
chapter — Sardar Ji's pawned auto-stand battery, Riya's three-parcel
instalment run, Monty's ninety-second pass hustle — each closing with
a proper outro conversation. More coming
every milestone.

## The legends
- **Jaspreet "Sardar Ji" Singh** — auto-rickshaw legend of Connaught Place
- **Riya Sharma** — delivery rider, fastest lanes in the city
- **Monty "Dilli ka Don" Malhotra** — Connaught Place hustler

## Controls
WASD / arrows — move · Shift — run · E — enter/exit vehicle · H — horn ·
N — cycle the in-vehicle radio (3 procedural stations) ·
Q / R — chai / samosa from street stalls · Space — advance dialogue,
confirm choice (W/S picks) · X / C — debug hurt / drop

**Gamepad** — left stick move · A interact · B horn · X radio ·
Y switch character · RB sprint · D-pad up/down chai/samosa · Start save.
**Touch** — on-screen joystick + buttons appears automatically on
touchscreen devices (also in the browser build on phones).

## ▶ Play in browser
**https://ayushsahnios.github.io/delhi-freetown-loot/** — deployed
automatically from master (single-threaded web export, works on plain
static hosting).

## Run it
Open this folder in **Godot 4.7+** and press F5, or headless:

```bash
godot --headless --import
godot --path .
```

Web export (any static host):

```bash
godot --headless --export-release "Web" build/index.html
```

## Roadmap
v0.2 Streets Alive (traffic AI, pedestrians, minimap, audio) →
v0.3 Wanted (police, heat) → v0.4 Paisa (missions, economy) →
v0.5 Kahani (three story arcs, character switching) →
v1.0 (Chandni Chowk, monsoon, radio). Full plan: [PLAN.md](PLAN.md)

## Legal
Original work. Game *mechanics* take inspiration from the open-world genre;
no code, assets, audio, names, or trademarks from any commercial game are
used anywhere in this project.
