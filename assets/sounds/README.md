# Sounds

Every sound here is [CC0](https://creativecommons.org/publicdomain/zero/1.0/)
(public domain), cut and converted from the packs below with
[`tools/prepare_sounds.sh`](../../tools/prepare_sounds.sh) (44.1 kHz Ogg
Vorbis, peaks normalized to -1 dBFS). Downloaded in October 2026.

| File | Source | Author |
|---|---|---|
| `pistol_shot.ogg` | Walther PPQ, close (`X_39P.wav`) from [The Free Firearm Sound Library](https://opengameart.org/content/the-free-firearm-sound-library) | Ben Jaszczak et al. |
| `casing_1..3.ogg` | `impactMetal_light_000/002/004` from [Impact Sounds](https://kenney.nl/assets/impact-sounds) | [Kenney](https://kenney.nl) |
| `magazine_drop.ogg` | `impactMetal_medium_001` from [Impact Sounds](https://kenney.nl/assets/impact-sounds) | [Kenney](https://kenney.nl) |
| `reload_magazine_out.ogg`, `reload_magazine_in.ogg`, `reload_slide.ogg` | `gunreload1.wav` from [Gun reload sounds](https://opengameart.org/content/gun-reload-sounds), split in three | SpringySpringo |
| `dry_fire.ogg` | `metalClick` from [RPG Audio](https://kenney.nl/assets/rpg-audio) | [Kenney](https://kenney.nl) |
| `melee_swing.ogg` | `cloth2` from [RPG Audio](https://kenney.nl/assets/rpg-audio) | [Kenney](https://kenney.nl) |
| `melee_hit.ogg` | `impactPunch_heavy_001` from [Impact Sounds](https://kenney.nl/assets/impact-sounds) | [Kenney](https://kenney.nl) |
| `weapon_switch.ogg` | `metalLatch` from [RPG Audio](https://kenney.nl/assets/rpg-audio) | [Kenney](https://kenney.nl) |
| `bullet_time_enter.ogg`, `bullet_time_exit.ogg`, `bullet_time_loop.ogg` | [Time Slow](https://opengameart.org/content/time-slow): the opening hit, the same hit sped up, and the drone after it as a seamless loop | MidFag |

How they are used (see `autoload/sound_fx.gd`):

- Gameplay sounds are positional and slow down (dropping in pitch) with the
  world in bullet time; on desktop the world is also muffled with a low-pass
  filter.
- Casings are pitched up about 2x so the metal plate samples ring like brass.
- The bullet-time sounds play at normal speed.
