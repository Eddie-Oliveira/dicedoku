# 9x9 balance study (v0.11)

Run: `.github/workflows/balance.yml` (script `godot/tests/sim_balance.gd`), 20 puzzles per row, 2026-10-30.

- **givens**: numbers shown at the start (of 81). **given 9s / 7-9**: how many of those are high numbers (7-8 need a d8, 9 needs a d10).
- **singles-solvable**: share of the empty cells a casual player can fill with simple logic (only one number fits a cell, or a number fits only one cell in a row/column/box). 100% = no advanced techniques needed.
- **turns**: a bot that always places correctly (so turns measure the dice economy, not puzzle skill). **9-wait turns**: turns where only 9s were left.
- **mode**: random = cells removed in any order (v0.10); even = givens spread evenly over the digits, extras to the highest digits; boost = even, plus the 9s get +2 and the 8s +1 (taken from 1-3).

| mode | target | givens (avg) | gen ms avg/max | given 9s | given 7-9 | singles-solvable | turns avg | turns p90 | 9-wait turns |
|---|---|---|---|---|---|---|---|---|---|
| random | 28 | 28.0 | 22 / 76 | 2.6 | 8.6 | 86% | 10.9 | 12 | 0.3 |
| even | 28 | 28.0 | 20 / 47 | 4.0 | 10.0 | 90% | 10.8 | 12 | 0.1 |
| boost | 28 | 28.0 | 55 / 173 | 6.0 | 13.0 | 87% | 10.9 | 12 | 0.0 |
| random | 32 | 32.0 | 12 / 31 | 3.3 | 9.9 | 92% | 10.4 | 11 | 0.2 |
| even | 32 | 32.0 | 9 / 12 | 4.0 | 12.0 | 98% | 10.0 | 11 | 0.1 |
| boost | 32 | 32.0 | 18 / 63 | 6.0 | 15.0 | 96% | 9.9 | 11 | 0.0 |
| random | 36 | 36.0 | 8 / 9 | 4.5 | 12.8 | 100% | 9.6 | 11 | 0.2 |
| even | 36 | 36.0 | 7 / 8 | 4.0 | 12.0 | 100% | 9.7 | 10 | 0.1 |
| boost | 36 | 36.0 | 7 / 8 | 6.0 | 15.0 | 100% | 9.7 | 11 | 0.1 |
| random | 42 | 42.0 | 5 / 6 | 4.7 | 14.4 | 100% | 9.2 | 10 | 0.5 |
| even | 42 | 42.0 | 5 / 6 | 5.0 | 15.0 | 100% | 8.9 | 10 | 0.3 |
| boost | 42 | 42.0 | 5 / 6 | 7.0 | 18.0 | 100% | 8.4 | 9 | 0.0 |
| seat relabel | spread of given 9s (max-min) | spread of given 7-9 | spread of bot turns |
|---|---|---|---|
| random (v0.10) | 3.0 | 3.9 | 1.1 |
| fair (new) | 0.0 | 0.0 | 0.5 |

## Decision
- Fair per-seat boards: digits are only swapped with digits that need the same dice and have the same number of givens. In v0.10 seats differed by 3 given 9s on average (and 3.9 given 7-9s); now 0.
- Levels: **Cozy 42, boost** (most help with 9s, fastest: beginners), **Adventurer 36, even**, **Hero 32, even**, **Legend 28, even** (about 10% of the puzzle needs more than simple logic). Blitz stays 4x4.
- Generation stays fast enough for phones (worst case under 0.2 s).
- Note: the bot is a perfect placer, so real players will take longer and feel the 9s more than the "9-wait" column shows. Revisit after playtests.
