# Dicedoku: Development Log

## Concept
A Yahtzee × Sudoku race. Every player gets the same procedurally generated, uniquely solvable grid (4×4 or 6×6) and fills it using five dice.

## Rules (v0.1)
- Dice have N faces (d4 on 4×4, d6 on 6×6).
- A turn gives up to 3 rolls of 5 dice. Double-tap a die to hold it between rolls.
- Tap a die, then a cell. If the value matches the cell's solution it is placed; otherwise +1 mistake. Either way the die is spent for the turn.
- Cells where the value is rule-legal (row/column/box) are highlighted: your sudoku-logic aid.
- End turn at any time. Final roll combos earn hints: Yahtzee = 2, run of 4+ consecutive values = 1.
- Score = turns + 2 × mistakes (lower is better). Finished players rank above unfinished ones.

## Architecture
- Single file: `dicedoku.html`, hosted as a Claude artifact. Capabilities: `db`, `user`.
- Shared seed means a shared puzzle, so the game is fair and needs no turn arbitration.
- Data: `games/{CODE}` holds `{size, seed, host, dice}`. `games/{CODE}/players/{uid}` holds each player's own state and is written only by that player. This avoids last-writer-wins conflicts.
- Realtime sync uses `onSnapshot` on the players collection.
- Pure logic sits between `//LOGIC-START` and `//LOGIC-END` markers so it can be tested in Node.

## Expansion hooks
- New grids: add an entry to `GRIDS` as `{br, bc, givens}` (box rows × box cols; N = br·bc).
- New dice: add an entry to `DICE` (faces function), then pass its key in the game doc.
- New roll mechanics: extend `roll()`, `combo()`, `endTurn()`.

## Hosting and access
Players must be signed in to Claude and have at least Contributor access, because the shared `db` only lets Contributors and above write. Share the artifact with that access level, then give friends the room code.

## Release log
### v0.1
- Initial build: lobby, room codes, 4×4 and 6×6, dice rolling/holding, placement, mistakes, hints, live leaderboard.

## Test log
| Date | Test | Result |
|---|---|---|
| 2026-10-29 | `node --check` on the extracted script | Pass |
| 2026-10-29 | 300 seeds × (4×4, 6×6): solution is valid, puzzle has exactly 1 solution, givens match the solution | 0 failures |
| 2026-10-29 | `combo()` on Yahtzee, run of 4, no combo | Pass |
| not yet | Live multi-player session in the hosted artifact | Pending: needs a real session with friends |

## Known limitations and backlog
- No server-side cheating protection (a modified client could read the solution). Fine for friends.
- Dice roll with `Math.random` on the client.
- Backlog: turn-based mode, shared dice, timed rounds, rematch button, more grids (e.g. 9×9 with d9), special dice.

## Design notes: v0.2 draft (9×9 and extra dice) — 2026-10-29
**Feasibility tests**
- 9×9 (3×3 boxes, 34 givens): 40 seeds generated with a worst case of 50 ms, all unique and consistent. No solver changes needed.
- Combo odds with 5 dice (200k rolls): d9 Yahtzee 0.018%, triple 10.4%, run of 4 7.6%. On d6: Yahtzee 0.07%, triple 21%, run of 4 15.5%.
- Conclusion: Yahtzee is effectively unreachable on d9, so combo rewards need rebalancing (e.g. triple = 1 hint, run of 4 = 1 hint, Yahtzee = bonus).

**Open design decisions**
- 9×9 dice: d9 (strict, consistent) vs. d6 plus a second kind of die.
- Extra dice candidates: Wild (player picks the face), Mirror (shows N+1−v, so each roll covers two values), Safe (a wrong placement costs no mistake), Scout (reveals the correct value for one empty cell).
- Extra dice rarity: replace one of the 5 dice vs. earn them as rewards.

### v0.2 (2026-10-29): 9×9 and the d8/d10 expansion dice
**Changes**
- Added the 9×9 grid (3×3 boxes, 34 givens).
- `DICE` registry replaced by a per-grid `dice` list of face counts in `GRIDS`. 4×4 uses 5×d4, 6×6 uses 5×d6, 9×9 uses d8, d8, d9, d10, d10.
- Dead faces: a die face above the grid size (d10 showing 10) cannot be placed. It is shown dashed and must be rerolled; selecting it gives a toast and no mistake.
- A d8 can never show a 9. Completability relies on the d9 and d10 dice. Rule for new sets: `max(dice) >= N`.
- Combos ignore dead faces. On 9×9 a triple also earns 1 hint (Yahtzee on d9 is far too rare).
- Dice now show their type (d8, d9, d10) under the number. Lobby rules text and version label updated to v0.2.
- Old v0.1 rooms still work because dice are derived from the grid size, not stored in the game doc (the `dice:'classic'` field is now ignored).

**Tests**
| Test | Result |
|---|---|
| `node --check` on the full script | Pass |
| Completability check: `max(dice) >= N` for 4, 6, 9 | Pass |
| Bot with perfect knowledge of cell choice (200 games per grid): median turns to finish | 4×4: 3, 6×6: 5, 9×9: 11 (p10 10, p90 13, max 23) |
| `combo()` with dead faces and the 9×9 triple rule | Pass |
| Live multi-player on 9×9 | Pending |

**Notes**
- Real players need to work out where values go, so human games will be slower than the bot's turn counts.
- Balance question for playtesting: whether 5 dice with 2 d10s makes 9×9 too slow, or too fast with triple hints.

### v0.3 (2026-10-29): DnD dice only, upgradable dice
**Requirement:** dice limited to d4, d6, d8, d10, d20. 9×9 starts on 5×d6 and upgrades incrementally.

**Changes**
- Removed the d9. `UPGRADES=[4,6,8,10,20]` is the only allowed chain.
- Starting dice per grid: 4×4 = 5×d4, 6×6 = 5×d6, 9×9 = 5×d6.
- Upgrade economy: every 4 correct dice placements earns 1 upgrade (hints do not count). Spend it with the Upgrade button, then tap a die to move it one step up the chain. Dice type is stored per player (`df`), with `plc` (placements) and `ups` (upgrades available).
- 9×9 can only be completed by upgrading, because a d6 cannot show 7, 8 or 9, and a d8 cannot show 9. A d10 is needed for 9s.
- Dead faces (above the grid size) stay unplaceable, with one exception: a natural 20 on a d20 is a wild placement that fills any empty cell correctly, at no mistake.
- Dice are always shown (as – before the first roll) so they can be upgraded between rolls. Rolled values are kept when a die is upgraded.
- Backward compatible: older player docs without `df`, `plc`, `ups` fall back to the grid's starting dice and zeros.
- Lobby rules text and version label updated to v0.3.

**Tests**
| Test | Result |
|---|---|
| `node --check` | Pass |
| Real script run in a stubbed DOM with a fake db, driven by a bot using the actual roll/cell/upgrade/endTurn functions, one game per grid | 4×4: done in 3 turns. 6×6: done in 8 turns. 9×9: done in 11 turns. All with 0 mistakes |
| Completability on 9×9 over 3000 seeds: minimum empty cells that a d6 can place (need ≥ 8 to earn the 2 upgrades for a d10) | 25 |

**Balance notes for playtesting**
- Upgrading all dice to d10 on 9×9 makes 1 in 10 faces dead. Upgrading to d20 makes more than half the faces dead, so it is a gamble for the natural 20.
- Players may upgrade dice on 4×4/6×6 too, which mostly hurts them. Possible later change: restrict upgrades to grids that need them.

### v0.4 (2026-10-29): Merchant and dice-pool engine building
**Changes**
- Currency: **gold**. +1 per correct placement (natural 20 included), +2 extra for hits with a Golden die. This replaces the v0.3 "every 4 placements = 1 upgrade" token (old `ups`/`plc` fields are ignored; `plc` is still tracked).
- **Merchant card** with 3–5 offers. Stock is deterministic per game and turn (`rng(seed*31+turn)`), so every player sees the same market on a given turn. One offer is always the Whetstone, so 9×9 is always completable.
- Offers: Whetstone (3g, upgrade a die one step, repeatable), Extra d4 (2g), d6 (4g), d8 (6g), d10 (8g), Mirror d6 (6g), Safe d6 (5g), Golden d6 (5g), Loaded d6 (7g), Hint scroll (6g), Extra roll this turn (3g). Everything except the Whetstone sells once per player per turn (`bt` list, reset on End turn).
- **Dice pool** is now variable size (starts at 5, max 8 via `MAXP`). New dice are stored as parallel arrays `df` (faces) and `dk` (kind). Dice bought mid-turn join immediately and are rolled on the next roll.
- **Abilities:** Mirror also places N+1−v. Safe means a wrong placement costs no mistake (die still spent). Golden gives +2 gold per hit. Loaded rolls twice and keeps the face that fits an empty cell when the first one does not.
- Combos now count only the first five dice (otherwise big pools would trigger a hint every turn). Yahtzee is "5 or more of a kind among them".
- `hold()` is now allowed whenever the dice have been rolled and rolls remain (the extra-roll item broke the old `rolls===3` test).
- Upgrade button removed (the Whetstone replaces it). Dice show their ability emoji. Lobby rules text updated. Version label v0.4.
- Extending: add an object to `SHOP`. Ability logic lives in `cell()` (placement rules) and `rollDie()`.

**Tests**
| Test | Result |
|---|---|
| `node --check` | Pass |
| Offers: 200 turns, always 3–5 offers, Whetstone first, no duplicates | Pass |
| Buying: no gold blocks, gold charged, once per turn, pool grows with padded arrays, new die rolls next roll, pool cap 8, Whetstone upgrades the chosen die and charges 3g | Pass |
| Abilities: Mirror places N+1−v (and a plain die does not), Safe has no mistake, Golden +3 gold total, plain +1, natural 20 is wild, Loaded beats a plain die on useful faces | Pass |
| Combos use first five dice only | Pass |
| Bot games using the merchant on the real functions | 4×4: 2 turns, 6×6: 4 turns, 9×9: 12 turns, all with 0 mistakes |
| Live multi-player session | Pending |

**Balance notes for playtesting**
- Extra dice make 4×4 and 6×6 very fast. Possible later change: scale prices or cap the pool by grid size.
- Gold income is flat (+1 per hit). Watch whether 9×9 players have too much gold left over.
- Loaded dice use the solution on the client to choose a face (a mild information leak, in line with the known no-anti-cheat limitation).

### v0.5 (2026-10-29): Roll → lock → place turn phases
**Requirement:** roll first, optionally reroll and choose faces to keep, lock the dice (automatically on the last roll, with no extra rolls or face manipulation afterwards), then place dice on the board.

**Changes**
- New per-player flag `lk` (locked). Turn phases:
  1. **Roll phase:** Roll (up to 3 rolls). Tapping a die holds or releases it. Held dice are not rerolled.
  2. **Lock:** the Lock dice button locks manually, and the 3rd roll locks automatically. Locking is irreversible for the turn.
  3. **Place phase:** tap a die, then a cell. Placement and selecting dice are refused before the lock ("Lock your dice first").
- After locking, rolling and holding are disabled. The Extra roll scroll cannot be bought (the button is disabled and `buy()` refuses it). Whetstones do not change rolled values, so they are not face manipulation. Dice bought after the lock join the pool but are unrolled (shown –) until the next turn.
- Tap behaviour: while rolling, a tap toggles hold. While locked, a tap selects the die for placement. The old double-tap logic is removed. Held styling is hidden once locked.
- End turn resets `lk`. Hints and merchant purchases remain available in any phase.
- Dice-pool-size, combos, shop, gold and abilities are unchanged. Lobby rules text and the help line under the dice updated. Version label v0.5.
- Cleanup: removed a leftover duplicate `hold` function from the edit.

**Tests**
| Test | Result |
|---|---|
| `node --check` | Pass |
| Before the first roll: no pick, no lock | Pass |
| After roll 1: not locked and cannot place | Pass |
| Simulated clicks: tap holds a die during rolling, held die survives a reroll | Pass |
| Manual lock freezes values, blocks Roll and hold, blocks the Extra roll purchase | Pass |
| Tap selects a die only while locked | Pass |
| End turn resets lock and rolls | Pass |
| Auto-lock on the third roll | Pass |
| Extra roll bought before locking works (4 rolls available) | Pass |
| Die bought after lock is unusable this turn | Pass |
| Bot games using hold, lock, place, shop on the real functions | 4×4: 3 turns, 6×6: 5, 9×9: 22 (this bot rerolls non-fitting dice and rarely uses the shop's extras), all 0 mistakes |
| Live multi-player session | Pending |

**Notes**
- The 9×9 bot takes about twice as many turns as in v0.4 (22 vs 12) because it can no longer place dice between rolls and shop mid-roll. Keep an eye on 9×9 length in playtests. Candidate tuning: cheaper dice, more gold per hit, or a 4th roll.

### v0.6 (2026-10-29): Lose condition, hint rework, caps, d10 wilds, completed-number marking
**Changes**
- **3 mistakes = lost.** `MAXMIS=3`. Third mistake sets `lost:true` on that player. All their actions are frozen and the merchant is replaced by a "you lost" banner. Leaderboard shows ☠ and ranks lost players last. Other players keep playing. Safe-die misses do not count.
- **Hints reworked.** A hint can only be used on a die you have locked and selected: it places that die in a correct cell for free (no mistake, counts as a placement and as one of the turn's placements). Hint acquisition is unchanged. Hints no longer fill arbitrary cells.
- **Pool max 9** (`MAXP`, was 8).
- **Hold cap 5** (`MAXH`): holding a sixth die is refused. Held dice are never rerolled (unchanged).
- **Placement cap 6 per turn** (`MAXPL`): counts every selected die (hit or miss, hints included). *Interpretation of "only 6 can be selected per roll": at most 6 dice can be placed per turn. If you meant that only 6 dice are rolled per roll, say so and we change it.*
- **d10 zero = wild.** A d10 now effectively shows 0–9. Internally a rolled 10 on a d10 is the zero (displayed "0" with ★). It can be placed in any empty cell and is always correct. This replaces the old dead face 10. A natural 20 on a d20 stays wild. Other values above the grid size are dead (e.g. d20 showing 10 on 9×9).
- **Completed numbers (QoL).** A tracker row under the board strikes through numbers that are fully placed. Dice showing a completed number are dimmed with ✓, cannot be held (toast: reroll it) and cannot be selected for placement. Mirror dice stay usable while the mirrored number is still open. Wild and dead dice are handled separately.
- Loaded die treats wilds as useful. Lobby rules, stats line (✗ n/3) and version updated.

**Tests (real functions, stubbed DOM and db)**
| Test | Result |
|---|---|
| `node --check` | Pass |
| Three mistakes → `lost`, further actions (roll, lock, hold, pick, end turn, buy) change nothing, banner renders | Pass |
| Hold cap: sixth hold refused, release works | Pass |
| Placement cap: with 8 dice only 6 can be placed | Pass |
| d10 zero: wild/dead definitions, placed in any cell correctly with no mistake, displayed as 0 ★; d20 10 dead, d20 20 wild | Pass |
| Completed numbers: counted, flagged useless, hold and place refused, mirror exception, tracker markup | Pass |
| Hint: needs lock, needs a selected die, places the die correctly and costs 1 hint | Pass |
| Bot games (hold/lock/place/shop) | 4×4: 3 turns, 6×6: 5, 9×9: 24, 0 mistakes |
| Live multi-player session | Pending |

**Notes**
- 9×9 stays around 24 turns for the bot. Playtest to judge whether it needs tuning (cheaper dice, more gold, 4th roll).
- Because hints now need a die, hint scrolls are weaker. Price (6g) is unchanged. Revisit after playtests.

### v0.7 (2026-10-29): Hand of 6, softlock fix
**Requirement (clarified):** "only 6 can be selected per roll" means only 6 dice get rolled per roll, chosen from the pool (max 9), to give more control over the hand before placing.

**Changes**
- **Hand and bench.** New per-player array `hn` (hand flags, `MAXHN=6`). Only hand dice are rolled; bench dice stay blank (–) and cannot be held or placed. Default hand is the first 6 dice (old player docs without `hn` use this default).
- Choosing the hand: tap a bench die to add it (if the hand has room). The **Swap** button (shown when the pool is over 6) toggles swap mode, where tapping any die moves it between hand and bench. Benching a rolled die clears its value and hold, so no more than 6 dice can carry values. A die added mid-turn rolls on the next roll. Hand changes are blocked once locked. The hand persists across turns.
- Bought dice join the hand if it has room, otherwise the bench.
- Roll is refused with an empty hand. Roll, lock and the Whetstone all exit swap mode.
- Combos now use the hand's rolled values (up to 6, zeros ignored).
- UI: "Hand n/6" label, hand row, dotted "Bench" row, Swap/Done button, rules text updated. Version label v0.7. Removed unused double-tap variables.
- **Softlock fix (bug found by testing, present since v0.4):** on 9×9, if only 9s remained, no die could show a 9 or wild, and gold was under 3, a player could never earn gold again and was stuck forever. Ending a turn with zero placements now pays 1 gold ("the merchant tips you"), so a Whetstone is always reachable.
- Process note: the artifact `edit` action is no longer available. Edits are now applied to the local file by script (each old string must match exactly once) and the file is published with the artifact URL. A v0.6 backup was kept in the scratchpad.

**Tests (real functions, stubbed DOM and db, simulated clicks)**
| Test | Result |
|---|---|
| `node --check` | Pass |
| 5 dice: all in hand, no Swap or Bench shown. 9 dice: first 6 in hand, Swap and Bench shown, "Hand 6/6" | Pass |
| Only hand dice rolled; bench die cannot be held; tap on bench die with full hand refused | Pass |
| Swap mode: benching a held, rolled die clears value and hold; adding a bench die; next roll uses the new hand with exactly 6 values | Pass |
| Tap on bench die outside swap mode adds it when there is room | Pass |
| Empty hand cannot roll | Pass |
| Buying: 6th die joins the hand, 7th goes to the bench | Pass |
| Locked: hand cannot change, Swap disabled. Hand persists across turns | Pass |
| Combos with zeros and 6 dice; old player doc default hand | Pass |
| Bot games (3 per grid) | 4×4: 3 turns, 6×6: 5–7, 9×9: 15–22, 0 mistakes |
| Softlock regression: 200 bot 9×9 games, 300-turn limit | Before fix: 6 of 40 stuck. After fix: 200 of 200 finish, median 22, max 32 turns |
| Live multi-player session | Pending |

**Notes**
- The bot is greedy (buys any die, rarely uses Whetstones beyond the first d10), so its 9×9 turn counts are pessimistic. A human picking the 6 best dice should be faster.

### v0.7.1 (2026-10-29): First live test, join timeout fix
**Bug report (first live test):** the second player opened the shared link, entered room code UVNJS and got a "timeout" error on Join.

**Diagnosis**
- The data store has no "timeout" error code. A timeout arrives as the transient `unavailable` code, which the platform docs say to retry. v0.1–v0.7 never retried, so a single slow call failed the whole join.
- The join also had no protection against double taps, and a failed join could leave the room half-entered.
- Separately, players without write access (Viewer, or a public link turned on) would get unclear errors.

**Changes**
- `tryDb()`: every load and save (join, create, moves) retries up to 4 times with randomized backoff on transient errors, and fails fast on permanent codes (`invalid_argument`, `quota_exceeded`, `revoked`, `not_granted`, etc.). Error messages now include the code.
- Join and Create check `can('data.write')` first. Without write access the player sees "You can only watch: ask the host to share the game with you as Editor". A write refused with `invalid_argument` shows the same message.
- Join shows "Joining CODE…", ignores double taps, says "Game CODE not found: check the code" for a wrong code, and on failure resets cleanly with "Tap Join to try again".
- Live player updates reconnect automatically if the platform drops the connection (`unavailable` on the listener).
- Version label v0.7.1.

**Tests (real functions with a fake store that injects failures)**
| Test | Result |
|---|---|
| `node --check` | Pass |
| Join with 2 injected timeouts succeeds and writes the player doc | Pass |
| 4 timeouts in a row: gives up with a clear message, state reset, no stuck "joining" flag | Pass |
| `invalid_argument` on write: no retries, "only watch" message | Pass |
| `can('data.write')` false: join blocked before any call | Pass |
| Wrong code: "not found" message | Pass |
| Rejoining keeps progress | Pass |
| Save retries a transient failure | Pass |
| Live updates resubscribe after `unavailable` | Pass |
| Create succeeds through a transient failure | Pass |
| Full gameplay regression (v0.7 suite) | 0 failures |
| Live multi-player session | Retest pending |

### v0.8 (2026-10-29): Turn-based play, curses between players, no dice limit
**Requirements:** remove the 6-dice roll limit; give each player their own turn; let players affect each other's rolls through merchant purchases.

**Changes**
- **No hand limit.** The hand/bench system (v0.7) is removed: every die in the pool rolls (pool still max 9). The "max 6 placements per turn" cap from v0.6, which came from a misreading of the original request, is also removed. Hold cap 5 stays. Combos count the first five dice again.
- **Turns.** Players act one at a time in join order (`joined` on each player doc). The game doc stores `cur` (whose turn) and `ts` (when it started). Only the current player writes `cur`, on End turn, or when they finish or lose, so there are no write races (the store has no transactions). Finished and lost players are skipped automatically. Anyone can **Skip** a player idle for 2 minutes. Out of turn, all controls and the merchant are disabled with "Wait for your turn". A "Your turn" banner and toast; the other player's live dice show in the Players list. Solo games always stay on your turn. Old rooms work: missing `cur` means the earliest joiner starts.
- **Curses.** The merchant always stocks the Whetstone plus one "versus" item: Hex (4g, rival loses 1 roll next turn), Blight (5g, 2 dice of the rival's next roll come up 1), Shackle (4g, rival can hold only 1 die next turn), or Ward (3g, blocks the next curse aimed at you; stackable). Total stock stays 3–5 offers.
- Curses are separate documents in `games/{CODE}/fx` (`to, from, fromName, k, at`), written by the sender and deleted by the target, so no two players write the same document. They take effect on the target's first roll of their next turn; applied ids are remembered (`fxi`) so a curse can never hit twice. Hex never takes away the first roll. Shackle state `shk` and the per-turn flag `fxd` reset at End turn.
- With 2 players the curse targets the rival automatically; with 3+ a "Curse target" picker appears. Pending curses show as 😈 on the target in the Players list and as a warning banner for the target.
- Live data now has three self-reconnecting listeners (players, game doc, curses).
- The page re-renders every 15 s while waiting so the Skip button appears on time.
- Rules text and version label v0.8.

**Tests: multi-client simulation** (each player a separate page context sharing one live fake store)
| Test | Result |
|---|---|
| `node --check` | Pass |
| Host goes first; both clients agree; the other player can't roll; banners; disabled controls and shop | Pass |
| 9-dice pool rolls all 9; 8 placements in one turn (no 6 cap) | Pass |
| End turn passes to the other player, who is notified; passer is blocked | Pass |
| Hex: delivered, charged, shown as pending, consumed, deleted; 2 rolls next turn | Pass |
| Blight: ≥2 ones on the first roll; Shackle: hold capped at 1, cleared at end of turn | Pass |
| Ward: bought, blocks a Hex, consumed | Pass |
| Buying out of turn is refused | Pass |
| Skip button only after 2 minutes idle; skip passes the turn | Pass |
| Third player joins mid-game, rotation A→B→C; target picker; targeted curse lands on the chosen rival | Pass |
| Losing (3 mistakes) passes the turn; loser skipped in rotation | Pass |
| Solo game keeps the turn | Pass |
| v0.7.1 join retry and permission tests on the new code | Pass |
| Full 2-player 9×9 bot games with curses, 3 runs | All finish; 11–29 turns per player; 0 mistakes |
| Live multi-player session | Retest pending |

**Notes**
- Curses make the game swingy; tune prices after playtests.
- No anti-cheat: a player's client deletes their own curses, so a modified client could ignore them (friends-only game).

### v0.8.1 (2026-10-29): Turn never passed (live test bug)
**Bug report (live test, room DMMJL, 9×9):** Jessica's first turn worked, but the game never passed to Eddie. Skip by Eddie seemed to do nothing; play continued on her turn.

**Evidence from the live database (read with the owner's access)**
- Game doc `cur` = Eddie (version 4), yet Jessica's player doc showed `turn: 3`, rolled after the turn had passed. Eddie's doc: `turn: 1`, never rolled.

**Root cause**
- Each screen decided whose turn it was from its own live copy of the player list. Jessica's screen had not loaded Eddie's player record (her live player listener had stalled or missed his join). To her client she was the only active player, so: (1) End turn passed the turn to herself; (2) a `cur` naming Eddie was treated as an unknown player and the turn fell back to her; (3) each time she ended a turn she wrote `cur` back to herself, undoing Eddie's Skip.
- Secondary risk: an older copy of the game doc arriving late could overwrite a newer turn.

**Fix**
- `curId()`: if `cur` names a player this screen hasn't loaded, wait for them instead of taking the turn.
- `passTurn()`: re-reads the player list from the server (`collection.get()`) before choosing the next player.
- Turn counter `tn` on the game doc, incremented by every pass and skip. An older game doc (lower `tn`) is ignored.
- Backup sync: every 8 s each screen re-reads the game doc and player list from the server (reads only), so a stalled live listener can't leave a screen out of date. This replaces the 15 s re-render timer.
- Skip refuses when there is no other active player ("No other player can take the turn").
- Unknown player names show as "Another player". The Players card shows "sync #n" (the turn counter) so two screens can be compared.
- Version label v0.8.1.
- No data repair needed: room DMMJL is already on Eddie's turn on the server. After a reload, Jessica's screen picks that up.

**Tests**
| Test | Result |
|---|---|
| `node --check` | Pass |
| New regression test reproducing the live bug (Jessica's player listener frozen after first delivery, so she never sees Eddie) on **v0.8** | Reproduced: 7 failures (turn returned to Jessica, she kept playing) |
| Same test on **v0.8.1**: turn passes to Eddie on server and both screens; Jessica can't keep playing; rotation continues; stale game snapshot ignored; a screen with all listeners frozen recovers via backup sync | 0 failures |
| Full v0.8 multiplayer suite (turns, curses, ward, skip, 3 players, losing, solo, 3 full 2-player 9×9 games) | 0 failures |
| Live multi-player session | Retest pending |
