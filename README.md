# Max Pain

A fan-made, Max Payne inspired third-person shooter prototype built with
[Godot 4](https://godotengine.org) (GDScript). The current focus is nailing the
core character mechanics: running, aiming, shooting, bullet time and the
signature **shootdodge**.

| Bullet time | Shootdodge |
|---|---|
| ![Bullet time](docs/screenshots/bullet_time.png) | ![Shootdodge](docs/screenshots/shootdodge.png) |

> Max Payne is a trademark of Remedy Entertainment / Rockstar Games. This is a
> non-commercial learning project and uses no original assets.

## Features

- **Third-person controller**: over-the-shoulder camera, the character always
  faces the aim direction and strafes/backpedals while shooting.
- **Bullet time**: eases the world to 30% speed while mouse aiming stays fully
  responsive. Adrenaline drains in real time and is refilled by kills. A
  full-screen effect (warm desaturation, vignette, chromatic aberration) fades
  in with the slowdown and sounds are slowed with it.
- **Pistol**: semi-automatic, 18-round magazine, auto-reload, recoil, muzzle
  flash. Bullets are **physical projectiles** (not hitscan), so you can watch
  them fly in slow motion. They knock props around.
- **Shootdodge**: dive in any direction in slow motion, keep shooting while
  airborne, land on the ground (you can still shoot while prone) and get back
  up.
- **Practice targets**: headshots deal triple damage; targets topple over
  physically when killed and respawn. Some of them patrol.

## Controls

Keyboard/mouse and controllers (Xbox, PlayStation 5 DualSense, PlayStation 4
DualShock and other standard gamepads) are supported on desktop and in the
browser. The controller layout follows Max Payne 3, and the on-screen prompts
switch automatically to the device you are using.

| Action | Keyboard / mouse | Xbox | PlayStation |
|---|---|---|---|
| Move | WASD / arrows | Left stick | Left stick |
| Aim | Mouse | Right stick | Right stick |
| Fire | Left click | RT | R2 |
| Shootdodge (with a direction) | Right click | RB or LT | R1 or L2 |
| Bullet time (toggle) | Shift or Q | LB or R3 (click) | L1 or R3 (click) |
| Jump | Space | A | Cross |
| Reload | R | X | Square |
| Help | F1 | Menu / View | Options / Create |
| Fullscreen | F11 | | |
| Release mouse | Esc | | |

The shootdodge button while standing still toggles bullet time, like in the
original game.

Controller extras:

- **Rumble** when firing and when landing a shootdodge.
- **Analog aiming** with a response curve for fine adjustments, a turn boost
  when holding the stick at the edge, and light aim friction while the
  crosshair is over an enemy.
- In the browser, press any controller button once so the page detects it.

## Running the project

1. Download **Godot 4.7** (standard version, not .NET) from
   <https://godotengine.org/download>. It runs on macOS, Windows and Linux.
2. Open Godot, click **Import** and select this folder's `project.godot`.
3. Press **F5** to play.

## Exporting builds (Windows, Linux, macOS, Web)

Export presets for all four platforms are already configured in
`export_presets.cfg`.

1. In the editor: **Editor > Manage Export Templates > Download and Install**.
2. **Project > Export...**, pick a preset and click **Export Project**. Builds
   are written to `build/<platform>/`.

Or from the command line:

```sh
godot --headless --export-release "Windows" build/windows/MaxPain.exe
godot --headless --export-release "Linux"   build/linux/MaxPain.x86_64
godot --headless --export-release "macOS"   build/macos/MaxPain.zip
godot --headless --export-release "Web"     build/web/index.html
```

Notes:

- The project uses the **Compatibility** renderer (OpenGL 3.3 / WebGL 2) so it
  looks the same everywhere, including the browser and older hardware.
- The macOS build is ad-hoc signed, not notarized. Players need to right-click
  the app and choose **Open** the first time.
- The Web build is single-threaded, so it needs no special server headers and
  can be uploaded as-is to itch.io or GitHub Pages. To test it locally, serve
  the folder over HTTP (for example `python3 -m http.server -d build/web`)
  instead of opening the file directly.

## Play online, PR previews and releases

The Web build is published to GitHub Pages and the desktop builds to GitHub
Releases, all by GitHub Actions:

| Workflow | When | What |
|---|---|---|
| `pages.yml` | push to `main` | Smoke test, then publishes the game at `https://vidalmatheus.github.io/maxPain/` |
| `pr-preview.yml` | every pull request | Playable preview at `https://vidalmatheus.github.io/maxPain/pr-preview/pr-<number>/` (the link is posted on the PR), with screenshots of the core mechanics in `.../shots/`. Removed when the PR is closed. |
| `release.yml` | tags like `v0.1.0` | GitHub Release with the Windows, Linux and macOS builds attached |

To publish a release:

```sh
git tag v0.1.0 && git push origin v0.1.0
```

One-time setup: GitHub Pages must be set to **Settings > Pages > Source:
Deploy from a branch > `gh-pages` / (root)**, so the main site and the PR
previews (in `gh-pages/pr-preview/`) live side by side. The `gh-pages` branch
is created by the first workflow run. On the free plan the repository must be
public.

To build locally (export templates required), use `tools/export.sh`:

```sh
tools/export.sh web          # or: windows linux macos, or: all
python3 -m http.server -d build/web
```

## Tests

A headless smoke test drives the main scene and checks walking, shooting,
kills, bullet time, shootdodge and reloading. It exits with code 0 when every
check passes:

```sh
godot --headless --path . res://tests/smoke_test.tscn
```

A second scene plays a scripted sequence and saves screenshots plus an
`index.html` gallery (it needs a renderer, so no `--headless`; CI runs it under
`xvfb-run`):

```sh
godot --path . res://tests/screenshots.tscn -- --output=/tmp/shots
```

## Project layout

```
autoload/
  bullet_time.gd       Global slow-motion controller and adrenaline meter
  game_input.gd        Default input bindings (keyboard, mouse, gamepad)
scenes/
  main.tscn            Test arena
  player/              Player controller, camera and placeholder model
  weapons/             Pistol and bullet
  targets/             Practice target dummy
  props/               Physics crate
  fx/                  Impact particles
  ui/                  HUD, crosshair and bullet-time screen shader
tests/                 Headless smoke test and screenshot sequence
tools/export.sh        Exports builds into build/<platform>/
.github/               CI: Pages deploy, PR previews, releases
```

Physics layers: `1 world`, `2 player`, `3 enemies`, `4 props`.

## Roadmap

- [x] Character movement, camera and aiming
- [x] Bullet time with adrenaline
- [x] Pistol with physical bullets
- [x] Shootdodge
- [ ] Animated character model (e.g. Mixamo) replacing the box placeholder
- [ ] Sound effects and music
- [ ] Enemy AI that shoots back, player health and painkillers
- [ ] More weapons (dual Berettas, shotgun, ...)
- [ ] Bullet cam on the last kill
- [ ] First level and graphic-novel style cutscenes
- [x] CI that publishes builds for every platform
