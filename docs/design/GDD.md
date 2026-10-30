# Dicedoku — Game Design Document (rules as of v0.10-dev)

Sources: `docs/design/v0.9.md`, `CHANGELOG.md`, `godot/core/{rules,game,bot,puzzle}.gd`.

## Idea
Each player has their own copy of the same sudoku (same seed). You roll dice, hold and lock them, then place
them on the grid. A correct die fills its cell and earns gold; a wrong one costs a mistake. Gold buys dice and
curses from Rook, the raccoon merchant. First to clear the grid wins on score.

## Grids

| Grid | Box (rows x cols) | Givens |
|---|---|---|
| 4x4 | 2x2 | 6 |
| 6x6 | 2x3 | 14 |
| 9x9 | 3x3 | 34 |

The same seed gives the same puzzle (identical to web prototype v0.8.1). Givens look carved into the stone.

## Dice

Start pool: 5 dice. Pool max 9. Hold max 5. Dice rolls per turn: 3.

| Grid | Starting dice |
|---|---|
| 4x4 | 5 x d4 |
| 6x6 | 5 x d6 |
| 9x9 | 5 x d6 |

- Faces: d4 shows 1-4, d6 1-6, d8 1-8, d10 0-9.
- No d20. Upgrade chain: d4 > d6 > d8 > d10.
- Wild: only the d10's zero. It can be placed on any empty cell and always hits.
- Dead face: a number larger than the grid (for example a 7 on a 6x6). It cannot be placed or held.
- Useless face: all cells of that number are already filled. It cannot be held or placed (a Mirror die stays usable while its mirror number is still open). Reroll it.

## A turn
1. **Roll.** First roll applies any pending curses (see below). Held and used dice keep their value.
2. **Hold** up to 5 dice (not used, dead or useless ones). Roll again, up to 3 rolls in total. **Lock** to stop early; after the last roll dice lock automatically.
3. **Place** each locked die on an empty cell. Correct value = hit (cell filled). Wrong = +1 mistake. Each die is used once.
4. **Shop** (optional, any time on your turn) and **End turn**.

Hints: a hint places a chosen die on the first cell where it fits. It costs 1 hint.

### Hits, mistakes, gold

| Event | Result |
|---|---|
| Hit | +1 gold (+2 more with a Golden die) |
| Miss | +1 mistake (Safe die: none) |
| 3 mistakes | You are out |
| Turn with no placements | +1 gold ("Rook tips you") and counts toward bot stall |
| Grid full | You finish |

### Combos (checked at end of turn on the first five rolled dice)

| Combo | Hints |
|---|---|
| Five of a kind | 2 |
| Run of 4 distinct values (within the grid size) | 1 |
| 9x9 only: three of a kind | 1 |

### Score and ranking
Score = turns + 2 x mistakes (lower is better). Results order: finished players by score (ties by who finished first),
then still playing (by cells filled), then eliminated.

## Rook's shop
Stock depends on the seed and your turn number; every player sees the same stock on a given turn.
Stock = Whetstone + one versus item (Hex, Blight, Shackle or Ward) + 1-3 random items from the list below.
Each item can be bought once per turn.

| Item | Cost | Effect |
|---|---|---|
| Whetstone | 3 | Upgrade one die a step (d10 is the top) |
| Extra d4 | 2 | Add a d4 to the pool |
| Extra d6 | 4 | Add a d6 |
| Extra d8 | 6 | Add a d8 |
| Extra d10 | 8 | Add a d10 |
| Mirror d6 | 6 | Also fits the mirror value (N+1-v) |
| Safe d6 | 5 | A miss costs no mistake |
| Golden d6 | 5 | +2 gold per hit |
| Loaded d6 | 7 | Rolls twice, keeps the useful face |
| Hint scroll | 6 | +1 hint |
| Extra roll | 3 | +1 roll this turn (not after locking) |

Pool full (9 dice) blocks buying dice.

### Curses (versus items)
Bought curses go to a rival's pending list (you choose the target; default is the next active rival) and fire at the
start of that rival's next first roll. Ward blocks one curse each.

| Item | Cost | Effect on the target |
|---|---|---|
| Hex | 4 | 1 fewer roll that turn (never below 1) |
| Blight | 5 | 2 free dice of the first roll come up 1 |
| Shackle | 4 | Can hold only 1 die that turn |
| Ward | 3 | Blocks the next curse aimed at you |

## Players and pets
1-4 seats. Turns go in seat order; finished or eliminated players are skipped. Each seat picks a unique pet
(Kitten Wizard, Puppy Knight, Fox Rogue, Bunny Bard); pets are cosmetic. With more than one human on one device a
"Pass the device" screen hides the board between turns; with one human it is skipped. No Skip button.

## Bots
Lobby seats are Human or Bot (easy, normal, hard). Bots play through the same actions as people (0.45 s per step).

| Level | Behavior |
|---|---|
| Easy | Simple logic; 30% of the time makes a risky (maybe wrong) guess |
| Normal | Only proven placements (naked and hidden singles); guesses after 3 stuck turns |
| Hard | Knows the solution |

Bots buy extra dice when useful, upgrade on 9x9, and (normal/hard) curse rivals when they have spare gold.
They never use the game's dice RNG, so replays stay identical.

## Online rooms (v0.10-dev)
- Host creates a room; a 5-letter code lets up to 4 seats join (humans or bots). Needs 2+ seats to start.
- Everyone plays the same game from the same seeds; only the seat whose turn it is can act.
- Rejoin after reload by name. The host may hand a seat idle for 90 s to a normal bot (action `botify`).
- Technical layout: see `docs/tech/ARCHITECTURE.md`.

## Look
Cozy tavern UI over an inked dungeon map; stone tiles, parchment panels, wood buttons, gem dice
(held = gold ring). Portrait 720x1280. Details: `docs/assets/STYLE.md`.
