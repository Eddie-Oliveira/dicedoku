# Dicedoku art style guide (v0.9)

Cozy fantasy tavern UI over an inked dungeon map. Cute, round, original animal adventurers. Dice are glowing gems.

## Palette
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

## Outlines
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
- Each pet owns an accent: kitten wizard blue `#4B5BB0`, puppy knight steel + red, fox rogue forest green `#3F6B4A`, bunny bard rose `#C2557A`.
- Must read at 64 px: check silhouettes (ears, hat, helmet) at that size.

## Do / Don't
- Do: gradients, simple shapes, clipPath, opacity. Keep files under 25 KB.
- Do: transparent background except board tiles and the map (opaque).
- Don't: `<text>`, fonts, raster images, `<style>` blocks, blur filters (Godot/ThorVG import).
- Don't: imitate existing characters, logos or game art. No lettering in emblems.
