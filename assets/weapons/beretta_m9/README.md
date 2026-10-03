# Beretta M9 (92FS)

| File | What it is |
|---|---|
| `beretta_m9.glb` | Pistol model with a separate magazine (`Magazine`), plus a loose magazine (`Gun001`) that the game hides. |
| `beretta_m9_*.png`, `beretta_m9_*.jpg` | Textures extracted from the `.glb` by the Godot importer. |

Used by `scenes/weapons/beretta.tscn`, which scales it to its real length
(21.7 cm), points the barrel along -Z with the grip at the origin and places
the muzzle. The magazine drops out with physics when reloading
(`scenes/weapons/gun_model.gd`).

## Source and credits

- **Title:** "Beretta M9"
- **Author:** [emran.bayati](https://sketchfab.com/emran.bayati) on Sketchfab
- **Source:** <https://sketchfab.com/3d-models/beretta-m9-d1200d9aa28f466484f7d3fdd7724e76>
- **License:** [Creative Commons Attribution 4.0 (CC BY 4.0)](http://creativecommons.org/licenses/by/4.0/)
- **Downloaded:** October 2026, glTF binary (`.glb`) with 1k textures.

Credit line requested by the license:

> "Beretta M9" (https://sketchfab.com/3d-models/beretta-m9-d1200d9aa28f466484f7d3fdd7724e76)
> by emran.bayati (https://sketchfab.com/emran.bayati) is licensed under
> Creative Commons Attribution (http://creativecommons.org/licenses/by/4.0/).

Changes made here: rescaled, reoriented, and the loose magazine is hidden.
