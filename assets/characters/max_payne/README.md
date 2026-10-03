# Max Payne character

## Files

| File | What it is |
|---|---|
| `max_payne_1.glb` | Static 3D model of Max Payne (no skeleton, no animations). |
| `max_payne_1_*.png`, `max_payne_1_6.jpg` | Textures extracted from the `.glb` by the Godot importer. |
| `max_payne_rigged.scn` | **Generated.** The model rigged onto the animation skeleton. |
| `animations.res` | **Generated.** The animations used by the game. |

The generated files are produced by `tools/build_character.gd` (see the
instructions at the top of that script). Rebuild them after changing the model
or the list of animations.

## Sources and credits

### 3D model

- **Title:** "Max Payne 1"
- **Uploaded by:** Stefano Cagnani ([BimboCattibo90](https://sketchfab.com/stefanocagnani1990)) on Sketchfab
- **Source:** <https://sketchfab.com/3d-models/max-payne-1-b6ffa273ad774c66a2ff202d85f58e94>
- **License shown on Sketchfab:** [Creative Commons Attribution 4.0 (CC BY 4.0)](http://creativecommons.org/licenses/by/4.0/)
- **Downloaded:** October 2026, glTF binary (`.glb`) with 1k textures.

Credit line requested by the license:

> "Max Payne 1" (https://sketchfab.com/3d-models/max-payne-1-b6ffa273ad774c66a2ff202d85f58e94)
> by BimboCattibo90 (https://sketchfab.com/stefanocagnani1990) is licensed under
> Creative Commons Attribution (http://creativecommons.org/licenses/by/4.0/).

Changes made here: rescaled to 1.8 m and rigged onto a humanoid skeleton with
automatic skin weights (`tools/build_character.gd`).

**Note:** according to its description on Sketchfab, this is the original
model from the first Max Payne game. Max Payne and the character's likeness are
owned by Remedy Entertainment and Rockstar Games. This is a non-commercial fan
project; if the rights holders ask, the model will be removed.

### Animations

- **Universal Animation Library** and **Universal Animation Library 2**
  (Standard/free versions) by [Quaternius](https://quaternius.com)
- **License:** [CC0 1.0 (public domain)](https://creativecommons.org/publicdomain/zero/1.0/)
- **Source:** <https://quaternius.itch.io/universal-animation-library>
  (also mirrored on GitHub, e.g.
  <https://github.com/NafisRayan/Animate-Rigged-Humanoid-No-Blender>)

The rig uses the same 65-bone humanoid skeleton as these libraries, so their
animations play directly on Max.
