# Dicedoku — Architecture (v0.10-dev)

Godot 4.5 project in `godot/`. Exported to the web and hosted on GitHub Pages.

## Folders

| Folder | Responsibility |
|---|---|
| `godot/core/` | Pure rules, no UI or network: `drng.gd` (seeded RNG, web parity), `puzzle.gd` (generator), `rules.gd` (constants, shop, combos), `player_state.gd`, `game.gd` (a match), `bot.gd` |
| `godot/ui/` | `main.gd`: all screens (lobby, pass, board, shop, party, results), built in code |
| `godot/net/` | `firebase.gd` (REST client for Realtime Database), `online.gd` (room, seats, action log, polling) |
| `godot/tests/` | Headless tests (`run_tests.gd` runs all `test_*.gd`), `shots.gd` (screenshots), `fake_backend.gd` (in-memory database), `fixtures_web_v081.json` |
| `godot/assets/` | SVG art: characters, dice, board, ui, icons (see `docs/assets/ASSETS.md`) |
| `prototype-web/` | Frozen web v0.8.1, reference only |

## Action flow
Every change to a match is an action dictionary passed to `Game.apply(act)`; it returns `{ok, msg}`.

| Action | Fields |
|---|---|
| roll, lock, end | none |
| hold, upg | `i` (die index) |
| place | `i`, `c` (cell) |
| hint | `i` |
| buy | `id`, `t` (target seat, -1 = next rival) |
| botify | `s` (seat) turns a seat into a normal bot |

- UI taps build actions and call `Game.apply`.
- Bots: `Bot.next_action(game)` returns an action; the UI/host applies it.
- Online: each action is also appended to the room log; other devices replay the log through `Game.apply`.
Because dice use a seeded RNG (`dice_seed`) and bots never touch it, all devices stay identical.

## Online room (Firebase Realtime Database)
URL: `https://dicedoku-ac99f-default-rtdb.firebaseio.com`. Rules allow read/write only under `rooms/$code`.

```
rooms/CODE            code = 5 letters
  cfg      size, seed, dice_seed, host, created
  started  bool
  seats/jNNN...  {name, pet, uid, bot}   keys sort = seat order (max 4)
  acts/a000000, a000001, ...             the ordered action log
```
- Only the seat whose turn it is may add actions; the host runs bot turns.
- Rejoin by name replays the whole log.
- Host can hand a seat idle for 90 s to a bot (`botify`).

## CI (`.github/workflows/tests.yml`)

| Job | When | What |
|---|---|---|
| `godot-tests` | every push / PR | Headless Godot 4.5; fails on any test failure or SCRIPT ERROR; results published as annotations |
| `screenshots` | `main` only | Renders key screens (720x1280) and force-pushes them to branch `ci-shots` |
| `web` | `main` only, after tests | Exports `stable` to the site root and `main` to `/dev/`, deploys one GitHub Pages site |

Tests include core rules, web parity, bots, UI, a two-device online room on the fake backend, and a live Firebase round trip.

## Links
- Players: https://eddie-oliveira.github.io/dicedoku/ (branch `stable`)
- Testing: https://eddie-oliveira.github.io/dicedoku/dev/ (branch `main`)

## Promote main to stable
Only after Eddie has playtested `/dev/` and CI on `main` is green: fast-forward `stable` to `main`
(`git push origin main:stable`, which fails if it is not a fast-forward). Then the next run on `main` (or a manual
run of the workflow) redeploys the site with the new stable at the root. Only runs on `main` may deploy Pages.
Add a CHANGELOG entry and a line in `docs/RELEASES.md`.
