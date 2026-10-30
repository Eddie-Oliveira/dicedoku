# Dicedoku art style guide (v0.11)

Cozy, cute, pastel tabletop adventure for all ages: soft storybook "sticker" look over a pastel adventure map. Cute, round, original animal adventurers. Dice are glowing gems (gem dice keep their v0.9 jewel colours).

## Pastel look (v0.11)
- Colours: peach, mint/sage, lavender, baby blue, butter yellow, blush pink on warm cream. No pure black anywhere.
- Outlines: warm soft brown `#7A5C4A` (details such as mouths and pupils `#5E4436`), round joins and caps, about 4 px on 64 px icons and 256 px characters, about 6 px on the 512 px merchant.
- Shapes: rounded and chunky; fur tufts on cheeks and chest, a little cowlick on top of the head.
- Eyes: big glossy ovals (rx 13.5, ry 16) with a brown-to-warm gradient, a lighter lower crescent and two white highlights (large top-right, small bottom-left). Blush ellipses `#FF9DB0` at 55 % with a tiny white dot.
- Shading: 2 tones or a light gradient plus one soft white highlight; no hard shadows.
- Decoration: small 4-point sparkles (white / butter `#FFF6C8`), tiny hearts `#FFB3C6`, near props and on emblems.
- Icons get a white "sticker" backing (the silhouette stroked 7 px white under the art) so they pop on dark and light backgrounds.
- Curses stay purple but lavender-soft; gold stays warm gold (`#FFD66E` fill, `#EBAE45` shade).

## Pastel UI palette (v0.11)
Contrast ratios are WCAG, measured against the panel fill `#FFF8EF` unless noted.

| Role | Hex | Notes |
|---|---|---|
| Page background | `#F8EDE3` | warm cream behind everything |
| Panel fill | `#FFF8EF` | `ui/parchment_panel.svg` centre |
| Panel border | `#B88A74` | 4 px soft brown; inner line `#EFC6B4` |
| Button fill | `#F7CF94` | honey; `ui/wood_bar.svg` runs `#FFE9C2` to `#EFBC7E`, border `#A97C5E` |
| Button text | `#5A3B2B` | 6.8:1 on `#F7CF94`, 5.8:1 on the darkest button edge |
| Body text | `#5A4136` | 8.9:1 (8.1:1 on page background) |
| Heading text | `#7A3F6A` | plum rose, 7.3:1; also for banner text (4.6:1 on the ribbon pink) |
| Muted text | `#86695C` | 4.8:1 |
| Accent / legal-cell glow | `#FFE08A` | butter; overlay or modulate on empty tiles |
| Gold | `#E8AE3C` | coins, held-die rim (fill only; gold text use `#9A6A12`, 4.5:1) |
| Curse | `#8456C0` | 4.9:1 as text; soft fills `#C9A8EE`, `#B48BE0` |
| Mistake red | `#B93E4C` | 5.2:1 as text; soft icon fill `#F28A94` |
| Success green | `#3A7D55` | 4.7:1 as text; soft icon fill `#A9E2B4` |
| Board frame | `#B9A8C9` | lavender grey between tiles (empty tile edge `#D8CEE5`) |
| Placed number | `#4F5BB0` | periwinkle indigo, 5.5:1 on empty tile centre `#F6F2FA` (4.5:1 at the tile edge); no outline needed |
| Given number | `#4A3343` | deep plum, 8.2:1 on given tile centre `#E7D6DF` |

## Legacy palette (v0.9-v0.10)
Still used by the gem dice and the legacy `pet_*` portraits; everything else moved to the pastel look above.

| Role | Hex | Use |
|---|---|---|
| Parchment | `#F1E3C6` | panels, map paper (edges `#D9C39A` / `#C9A874`) |
| Ink | `#3B2A1A` | every outline, map lines |
| Wood | `#6B4426` | bars, handles (light `#8A5A34`, dark `#4E2F18`) |
| Stone | `#8A8580` base, `#C9C4BD` light center, `#5E5A55` given | board tiles |
| Torch | `#FFB347` | glow, placed-number light, lantern |
| Curse | `#8E44AD` | hex, blight, shackle (light `#C98CF0`, dark `#5E2488`) |
| Gold | `#E2B33C` | coins, trims, held-die rim (dark `#A7781C`) |
| Mistake red | `#B5442C` | errors, target, knight shield |
| OK green | `#4E8A3E` | safe, plus badges |
| Gems | d4 teal `#1A9A8E`, d6 ruby `#C42A42`, d8 sapphire `#2F5FC4`, d10 amethyst `#8E44AD` |

## Outlines (legacy v0.9-v0.10; see Pastel look for v0.11)
- Ink `#3B2A1A`, round joins and caps.
- Weight about 1/16 of the asset side: 4 px on 64 px icons, 4 px on 128 px dice, 5 px on 256 px portraits, 6-7 px on the 512 px merchant.
- Map lines stay at 15-25 % opacity so board numbers win.

## Dice (128x128, no numbers)
- d4 = rounded triangle, d6 = cushion square, d8 = rhombus, d10 = kite (hex-shaped table).
- Each has: soft outer glow, radial body gradient, 4 facet wedges, a ~56 px pale "table" in the center for the number, a white streak highlight and one cream sparkle.
- States (held/used/dead/wild) are drawn in code on top: gold rim, opacity, grey modulate, sparkle.

## Characters
- Chibi: head is ~55-60 % of the figure height, eyes large ovals with two white catchlights, rosy cheek ellipses.
- Portraits: head-and-shoulders on a 256 box, head centered at x=128, one prop on the right/left edge.
- Legacy pet portraits (`pet_*.svg`, v0.9) are replaced by race + class layers. Each pet owned an accent: kitten wizard blue `#4B5BB0`, puppy knight steel + red, fox rogue forest green `#3F6B4A`, bunny bard rose `#C2557A`.
- Must read at 64 px: check silhouettes (ears, hat, helmet) at that size.

## Character layers (v0.10)
Players pick a race and a class; the game stacks `characters/class_<id>.svg` over `characters/race_<id>.svg`, same size and position (256x256, viewBox 0 0 256 256, transparent).
- Races: cat, dog, fox, bunny, bear, mouse. Classes: wizard, knight, rogue, bard, cleric, ranger.
- Shared template (every race keeps these exactly):
  - Head: rounded shape x 66-190, y 44-156, centre about (128, 100). Eyes at (102, 106) and (154, 106); nose about y 125; blush at (82, 128) and (174, 128).
  - Ears may go above the head: cat/fox up to y 12-18, bunny up to y 8, bear/mouse round ears out to x 39-217 at y 33-95, dog ears hang down the sides (x 46-210).
  - Torso (undershirt `#F1E3C6`): `M102 146 Q128 140 154 146 Q168 184 168 222 Q128 232 88 222 Q88 184 102 146 Z`.
  - Arms: strokes from (106,160) to (80,192) and (150,160) to (176,192); hands are r=11 circles at (78,196) and (178,196).
  - Feet: ellipses at (106,235) and (150,235), rx 17 (bunny 20), ry 10. Tail sits behind the body to the right (x 150-230).
- Class overlays draw only: outfit body `M96 150 Q128 166 160 150 Q174 186 176 228 Q128 240 80 228 Q82 186 96 150 Z` (covers the torso), sleeves along the arm strokes, headwear, one prop.
  - Headwear sits low between the ears (band at y 56-96, x 70-186) or is a hood with an open face (face hole x 74-182, y 66-158) so it fits tall, round and floppy ears alike. Do not cover the eyes (y 90-122).
  - Props: right hand (178,196) holds staff/sword/dagger/mace; left hand (78,196) holds shield/lute/bow. Keep props inside x 30-230 and y 4-254.
- Outline 4 px `#7A5C4A` (v0.11). Check new races/classes by compositing all pairs into a contact sheet at 128 px and 256 px.

## Effects (v0.10)
`effects/` holds animation sprites (128x128 unless noted). Glows use radial gradients that fade to opacity 0 at the edge so they can be scaled/tweened in code. Check them on parchment and on ink backgrounds.

## Do / Don't
- Do: gradients, simple shapes, clipPath, opacity, stroke-dasharray. Keep files under 20 KB.
- Do: transparent background except board tiles and the map (opaque).
- Don't: `<text>`, fonts, raster images, `<style>` blocks, blur filters (Godot/ThorVG import).
- Don't: imitate existing characters, logos or game art. No lettering in emblems.
