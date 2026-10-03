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

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | WASD / arrows | Left stick |
| Aim | Mouse | Right stick |
| Fire | Left click | Right trigger |
| Jump | Space | A |
| Bullet time (toggle) | Shift or Q | Right bumper |
| Shootdodge | Right click + direction | Left trigger / left bumper + direction |
| Reload | R | X |
| Help / fullscreen | F1 / F11 | Back |
| Release mouse | Esc | |

Right click while standing still toggles bullet time, like in the original game.

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

## Tests

A headless smoke test drives the main scene and checks walking, shooting,
kills, bullet time, shootdodge and reloading:

```sh
godot --headless --path . res://tests/smoke_test.tscn
```

It exits with code 0 when every check passes.

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
tests/                 Headless smoke test
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
- [ ] CI that publishes builds for every platform
