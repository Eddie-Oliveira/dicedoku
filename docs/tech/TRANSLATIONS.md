# Translations

Languages: English (source), Português (Brasil) `pt_BR`, Español `es`, Français `fr`, Italiano `it`, 简体中文 `zh_CN`.

- Code: `godot/core/lang.gd`. Source strings are the English text; `Lang.t("Roll")` looks it up, `Lang.f("{0} cleared the dungeon!", [name])` formats with `{0}`, `{1}`... (translations may reorder them). `lbl()`, `btn()`, `toast()` and floating texts translate automatically. Ambiguous keys live in `Lang.KEYED` (e.g. `HERO_TITLE`).
- Tables: `godot/i18n/<code>.json` map every English source string to its translation. Missing entries fall back to English.
- The player picks the language on the home screen (saved in `user://settings.cfg`); first launch follows the device locale.

## Adding or changing text
1. Write the English text in the code (inside `Lang.t` / `Lang.f`, or `lbl`/`btn`/`toast`).
2. Run `python3 tools/extract_strings.py` and commit `godot/i18n/source_en.json` (CI fails if it is out of date).
3. Add the new strings to every `godot/i18n/<code>.json` (keep `{n}` placeholders and leading/trailing spaces). `tests/test_i18n.gd` checks completeness and placeholders.
4. When `zh_CN.json` changes, the `fonts` workflow rebuilds `godot/assets/fonts/NotoSansSC-subset.ttf` (Noto Sans SC, SIL Open Font License, see `OFL-NotoSansSC.txt`) with only the characters used, and commits it. Then run the `tests` workflow by hand (bot commits don't trigger it).

## Review before the full release
Machine-quality translations by the translation agent (2026-10-30). Ask native speakers to review, especially: hero title word order, articles in "{0} the {1}", curse names, short button labels (fr "Réinitialiser" is long), the Loaded-die word, and zh_CN overall.
