# Dicedoku — Project Changelog (single source of truth)

Every change by any agent (or by hand) gets ONE entry here, newest at the top.
Agents read only the entries tagged with their area, e.g.:

    grep -n -A12 "areas:.*CODE" CHANGELOG.md | head -80

## Entry format (copy exactly)

```
### [YYYY-MM-DD] vX.Y(-dev) · <short title>
areas: DESIGN | CODE | ASSETS | DOCS   (list every area affected)
agent: design | code | assets | docs | lead
- What changed and why (1–5 bullets)
- Files: path/one, path/two
- Tests: what was run and the result (CI run link or "n/a")
- Needs: follow-up for another area, e.g. "ASSETS: raccoon merchant idle sprite" (or "none")
```

Rules
- One entry per finished change; no entry for work in progress.
- "Needs" lines are how areas hand work to each other. The receiving agent closes it by
  writing its own entry that starts with "Closes: <title of the entry it answers>".
- Never rewrite old entries; correct them with a new entry.

---

### [2026-10-29] v0.10-dev · GDD, ARCHITECTURE and RELEASES
areas: DOCS
agent: docs
Closes: Online rooms, bots, art in the UI, stable/dev links (DOCS part); Godot port: rules core, plain UI, web build (DOCS part)
- First GDD (rules as of v0.10-dev), architecture notes (folders, action flow, Firebase layout, CI, promote steps) and player-facing release notes for v0.8.1, v0.9, v0.10-dev.
- Written from v0.9.md, this CHANGELOG and core/{rules,game,bot,puzzle}.gd; no rules invented.
- Files: docs/design/GDD.md, docs/tech/ARCHITECTURE.md, docs/RELEASES.md
- Tests: n/a
- Needs: DESIGN: confirm GDD wording of useless/dead faces and shop-once-per-turn. CODE: stale comment in game.gd header ("online replay later"); check results order text matches UI.

### [2026-10-30] v0.11-dev · Difficulty levels, fair boards, slide-up tabs, dice tuner, pastel UI
areas: CODE | DESIGN
agent: lead (code role)
- Modes: Blitz 4x4, or 9x9 Cozy (42 shown, boost), Adventurer (36, even), Hero (32, even), Legend (28, even). 6x6 removed from the lobby (engine still supports it). Room cfg carries givens + quota mode.
- Generator: `Puzzle.generate(n, seed, givens, mode)`; "even" spreads givens over digits (extras to the highest), "boost" adds 9s/8s. Legacy path unchanged (web parity tests still pass).
- Fairness fix: per-seat relabel only swaps digits with the same dice class and given count (v0.10 seats differed by ~3 given 9s). Small grids retry until every seat's board differs.
- Balance study (`tests/sim_balance.gd`, workflow `balance.yml`): results and decision in docs/design/balance-9x9.md.
- Shop and party moved to a bottom tab bar with slide-up drawers (mobile space). Toasts sit above the bar.
- Dice number tuner (lobby): per die type x/y/size sliders, saved on the device, "Copy code" for Claudio to bake in (`DIE_TUNE_DEFAULT`).
- Pastel palette from docs/assets/STYLE.md applied (text, buttons, board frame, placed/given numbers, glow, ribbon, floating text); gem dice keep a dark number outline.
- Files: godot/core/{puzzle,game}.gd, godot/net/online.gd, godot/ui/main.gd, godot/tests/*, .github/workflows/balance.yml, docs/design/balance-9x9.md
- Tests: CI 44 tests, 0 failures before the palette commit (see run for this one); balance run 41096371000.
- Needs: DESIGN: Eddie sends the dice tuner code; playtest levels. ASSETS: legacy pet_* portraits can be retired.

### [2026-10-30] v0.11-dev · Pastel cozy restyle of all art (except gem dice)
areas: ASSETS
agent: assets
- Playtest request: whole look moved to cozy, cute pastel (peach, mint, lavender, baby blue, butter, blush) with soft brown #7A5C4A outlines, glossy eyes, blush, fur tufts, sparkles/hearts and a sticker feel. Original designs (reference image used only for mood).
- Restyled with same names, sizes and viewBox: 6 race + 6 class layers (template coords unchanged, 36 pairs re-checked), Rook, map, both tiles, panel, button bar, logo, 16 icons, 8 effects. Gem dice and legacy pet_* untouched.
- STYLE.md: "Pastel look (v0.11)" rules + "Pastel UI palette (v0.11)" hex table (all text colours >= 4.5:1 on panel); ASSETS.md updated, icons/quill.svg row added.
- Files: godot/assets/{characters,board,ui,icons,effects}/*.svg (except pet_*), docs/assets/STYLE.md, docs/assets/ASSETS.md
- Tests: all rendered with sharp; contact sheets reviewed (races, 36 pairs at 256/128/64, Rook, map, tiles with numbers, panel/button 9-sliced, icons on page/panel/dark); XML, size, viewBox, forbidden-element and <20 KB checks pass for all 51 SVGs.
- Needs: none (palette applied by the code role in the same release).

### [2026-10-30] v0.10 · Released to stable
areas: DOCS | CODE
agent: lead
- Eddie approved: main promoted to branch `stable` (site root); tag `v0.10`. Version label and project version set to 0.10; docs/RELEASES.md updated.
- Files: godot/ui/main.gd, godot/project.godot, docs/RELEASES.md
- Tests: CI on the release commit (see run); live check of the root URL by Eddie
- Needs: none

### [2026-10-29] v0.10-dev · Playtest round 2 + friends-and-family polish
areas: CODE | DESIGN
agent: lead (code role)
- Rules from Eddie's playtest: each seat gets its own board (same puzzle relabelled/shuffled, so equal difficulty; verified by identical deduction closure); Blight now hits when the target locks (2 random unplaced dice become 1s); Shackle costs 10g; Mirror can be placed as value -1, value or value +1; unused rolls pay 1 gold each on lock or end of turn; new shop item Scribe's quill (4g, 3 memos showing a tile's possible numbers).
- Gold rules shown in the shop header and How to play; every gold gain says how much and why.
- Online room: host can change a bot's level or remove it before the start.
- Race (cat, dog, fox, bunny, bear, mouse) + class (wizard, knight, rogue, bard, cleric, ranger) per seat; portraits stack class over race layers. Classes are cosmetic until skills arrive.
- Animations: every action returns fx events (roll, hold, lock, gold, hit, miss, safe, curse, ward, blight, cast, buy, upgrade, memo, combo, win, out); the UI plays them (dice tumble, cell glow/sparkles, board shake, purple curse flash, floating gold, turn ribbon). Online devices animate received actions too.
- Sound: 12 original effects generated by `tools/make_sfx.py`; Sound on/off button.
- Die numbers centred; How to play rewritten in sections.
- Offer parity with the web prototype dropped (new shop item); generator, rng and combo parity kept.
- Files: godot/core/*, godot/net/online.gd, godot/ui/main.gd, godot/tests/*, tools/make_sfx.py, godot/assets/sfx/*
- Tests: CI 40 tests, 0 failures, incl. per-seat layouts, gold for unused rolls, blight at lock, mirror +-1, scribe, fx events, bot seat editing, live Firebase round trip.
- Needs: DESIGN: playtest with friends and family on /dev/, then promote to stable. ASSETS: class skill icons when skills are designed.

### [2026-10-29] v0.10-dev · Chibi race + class character layers, new Rook, effect sprites
areas: ASSETS
agent: assets
- 6 race layers (cat, dog, fox, bunny, bear, mouse) on one shared 256x256 chibi template (head centre ~128,100; neutral undershirt torso; hands at 78/178,196; feet y 225-245) so any class fits any race.
- 6 class overlays (wizard, knight, rogue, bard, cleric, ranger): outfit over the torso, low headwear or open-face hoods that fit all ear shapes, one prop per hand; all 36 combinations composited and reviewed.
- Rook the raccoon merchant redrawn in chibi style (hooded cloak, waving, lantern, backpack of gem dice), 512x512. Old pet_* portraits kept as legacy fallback.
- New effects/ folder: sparkle, hit_glow, miss_crack, curse_burst (128); coin_pop, lock, quill (64); banner_ribbon (512x96).
- Files: godot/assets/characters/{race_*,class_*,merchant_raccoon}.svg, godot/assets/effects/*.svg, docs/assets/STYLE.md, docs/assets/ASSETS.md
- Tests: all 21 SVGs rendered with sharp; contact sheets of each race alone + 36 race x class pairs checked; effects checked on light and dark; XML, size and forbidden-element checks pass; all under 10 KB.
- Needs: none (wired in by the code role in the same release; quill copied to icons/quill.svg for the shop).

### [2026-10-29] v0.10-dev · Online rooms, bots, art in the UI, stable/dev links
areas: CODE | DESIGN | ASSETS
agent: lead (code role)
- Playtest fix (also on `stable`): board lines between some columns/rows vanished when the page scaled (1 px borders). Lines are now 3/7 px gaps over a dark frame; checked on a phone-sized screenshot (`08_board_phone`).
- Two live links: branch `stable` at https://eddie-oliveira.github.io/dicedoku/ (what players use), branch `main` at /dev/. Only runs on `main` may deploy to Pages; each deploy builds both branches. Promote = fast-forward `stable` to `main`.
- `Game.apply(action dict)` is the single entry point for UI, bots and online replay. New action `botify` hands a seat to a normal bot.
- Bots (`core/bot.gd`): easy (simple logic, 30% risky guesses), normal (proven placements only: naked/hidden singles; guesses after 3 stuck turns), hard (knows the solution). Bots never use the game's dice RNG, so replays stay identical. Lobby seats are Human / Bot (easy/normal/hard); bot turns play themselves (0.45 s per step); no pass screen when only one human.
- Online (`net/firebase.gd`, `net/online.gd`), Firebase Realtime Database https://dicedoku-ac99f-default-rtdb.firebaseio.com (rules: read/write only under `rooms/$code`): room code of 5 letters; `rooms/CODE` holds cfg (size, seed, dice_seed, host), seats (ordered keys), started flag and the action log `acts/a000000…`. Every device builds the same Game and applies the same actions; only the seat whose turn it is may add actions; the host runs bots. Rejoin by name after reload replays the whole log. Host may hand a seat idle for 90 s to a bot.
- Art wired in: dungeon-map background, parchment panels, wood buttons, stone tiles (given = carved), gem dice with big outlined numbers and a type label, held/selected rings, pet portraits (lobby, banner, pass screen, party, results), Rook in the shop, item icons, logo emblem.
- Files: godot/core/{game,player_state,bot}.gd, godot/net/*, godot/ui/main.gd, godot/tests/{test_bot,test_online,test_firebase_live,fake_backend,test_ui,shots,run_tests}.gd, .github/workflows/tests.yml
- Tests: CI 35 tests, 0 failures, including bot soundness, bot matches at every level, exact replay, two-device online room on an in-memory backend, idle seat handoff, and a live round trip on the real Firebase database (room created, joined, started, one turn synced, deleted). Screenshots reviewed.
- Needs: DESIGN: Eddie playtest online + bots on /dev/; decide when to promote to stable. DOCS: GDD + ARCHITECTURE + RELEASES for v0.9 and v0.10-dev. ASSETS (later): die-face animations, curse sparkle effect, sounds.

### [2026-10-29] v0.9-dev · Godot port: rules core, plain UI, web build
areas: CODE | DESIGN
agent: lead (code role)
- Rules ported to `godot/core/` (DRng, Puzzle, Rules, PlayerState, Game) following `docs/design/v0.9.md`: no d20 (chain d4>d6>d8>d10, the d10 zero is the only wild), local pass-and-play for 1-4 seats, pets, curses go to the target's pending list.
- Same seed gives the same puzzle and shop stock as the web prototype (parity fixtures from its JS in `godot/tests/fixtures_web_v081.json`).
- Plain interface in `godot/ui/main.gd`: lobby (grid, 1-4 players, names, pets), pass-the-device screen, board with legal-cell highlight, dice, Rook's shop with curse target, party list, results.
- CI: tests + screenshots of key screens pushed to branch `ci-shots` + browser build deployed to GitHub Pages.
- Files: godot/core/*, godot/ui/*, godot/tests/*, godot/export_presets.cfg, godot/project.godot, docs/design/v0.9.md, .github/workflows/tests.yml
- Tests: see CI run for this commit
- Needs: ASSETS: none yet (art pass next). DESIGN: Eddie playtest of the plain build. DOCS: GDD + ARCHITECTURE from this entry.

### [2026-10-29] v0.9-dev · First art pass: tavern, pets, gem dice
areas: ASSETS
agent: assets
- First original SVG art pass for the v0.9 look: raccoon merchant Rook, 4 pet portraits (kitten wizard, puppy knight, fox rogue, bunny bard), gem dice d4/d6/d8/d10 with a pale number area, parchment dungeon map, stone tiles (normal + carved given), parchment 9-slice panel, wood bar, dice emblem, 15 item/curse/status icons.
- Style guide in docs/assets/STYLE.md; asset table with licenses in docs/assets/ASSETS.md.
- Hand-written SVG using only gradients and shapes (no text, fonts, rasters, style blocks or filters) for Godot/ThorVG import; all under 9 KB.
- Files: godot/assets/{characters,dice,board,ui,icons}/*.svg (30 files), docs/assets/STYLE.md, docs/assets/ASSETS.md
- Tests: every SVG rendered to PNG with sharp and checked visually; XML, size and forbidden-element checks pass for all 30.
- Needs: CODE: in-engine check of the SVG import and the parchment_panel 9-slice (32 px margins); draw dice numbers and held/used/dead/wild states on the gem bodies.

### [2026-10-29] v0.9-dev · CI reports test results as annotations
areas: CODE
agent: lead
- First CI run passed (smoke suite). The run logs can't be downloaded from the agent workspace, so the workflow now publishes the test count as a notice and each failure as an error annotation, readable with `gh api repos/Eddie-Oliveira/dicedoku/check-runs/<id>/annotations`.
- Files: .github/workflows/tests.yml
- Tests: CI run on this commit (see Tests annotation)
- Needs: none

### [2026-10-29] v0.9-dev · Project split: Godot 4 port, agents, CI
areas: DESIGN | CODE | ASSETS | DOCS
agent: lead
- Web prototype frozen at v0.8.1 in `prototype-web/` (playable HTML + its full dev log `DEVLOG-web.md`).
- Official version moves to Godot 4 in `godot/`. Online multiplayer decided later; v0.9 targets local pass-and-play.
- Four agents defined in `.claude/agents/`: design, code, assets, docs. This file is their shared log.
- CI (`.github/workflows/tests.yml`) runs the Godot logic tests headless on every push.
- Files: CHANGELOG.md, README.md, .claude/agents/*, .github/workflows/tests.yml, godot/project.godot, godot/tests/run_tests.gd
- Tests: pipeline smoke test (first CI run pending)
- Needs: CODE: port core rules (generator, dice, merchant, curses, turns) from prototype-web v0.8.1, without the d20.
  DESIGN: approve the v0.9 scope (no d20; tavern + dungeon-map theme; raccoon merchant; pet characters chosen on join; gem dice).
  ASSETS: style guide + first asset list for v0.9.
  DOCS: create docs/design/GDD.md and docs/tech/ARCHITECTURE.md from the prototype dev log.
