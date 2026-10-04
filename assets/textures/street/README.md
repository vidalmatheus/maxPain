# Street textures

Every texture here comes from [ambientCG](https://ambientcg.com), all
[CC0](https://creativecommons.org/publicdomain/zero/1.0/) (public domain),
1K JPG downloads from October 2026. They are prepared with
[`tools/prepare_textures.py`](../../../tools/prepare_textures.py), which
resizes them for the web, draws the joints between the sidewalk's slabs and
lights a random quarter of the facades' windows (the `_emission` maps).

| Files | Source |
|---|---|
| `asphalt_color.jpg`, `asphalt_normal.jpg` | [Asphalt026C](https://ambientcg.com/a/Asphalt026C) |
| `sidewalk_color.jpg`, `sidewalk_normal.jpg` | [Concrete044D](https://ambientcg.com/a/Concrete044D) |
| `facade_a_color.jpg`, `facade_a_emission.jpg`, `facade_a_normal.jpg` | [Facade018A](https://ambientcg.com/a/Facade018A) |
| `facade_b_color.jpg`, `facade_b_emission.jpg`, `facade_b_normal.jpg` | [Facade020A](https://ambientcg.com/a/Facade020A) |
| `tower_color.jpg`, `tower_emission.jpg` | [Facade009](https://ambientcg.com/a/Facade009) |
| `snow_color.jpg`, `snow_normal.jpg` | [Snow010A](https://ambientcg.com/a/Snow010A) |

They are imported as lossy WebP with mipmaps (see the `.import` files) to
keep the web download small.
