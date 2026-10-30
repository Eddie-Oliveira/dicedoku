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
