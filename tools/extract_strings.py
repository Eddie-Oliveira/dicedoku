"""Collects the English source strings the game translates (Lang.t / Lang.f calls, ui helpers,
and the text tables in rules.gd / main.gd). Writes i18n/source_en.json (sorted list).
Run from the repo root: python3 tools/extract_strings.py"""
import json, re, os
ROOT = os.path.join(os.path.dirname(__file__), "..", "godot")
FILES = ["ui/main.gd", "core/game.gd", "core/rules.gd", "net/online.gd"]
LIT = r'"((?:[^"\\]|\\.)*)"'
CALLS = [r'Lang\.t\(' + LIT, r'Lang\.f\(' + LIT, r'\blbl\(' + LIT, r'\bbtn\(' + LIT, r'\btoast\(' + LIT,
         r'float_text\(' + LIT, r'"(?:n|d|text|name)": ' + LIT, r'return ' + LIT,
         r'\bpanel\(' + LIT, r'\belse ' + LIT, r':= ' + LIT + r' if ']
SKIP = re.compile(r'^(|[a-z_0-9./:%]+|res://.*|user://.*|.*\.svg|.*\.wav|cell_%d|die_%d|[a-z]+_[a-z_]+)$')
out = set()
for f in FILES:
    src = open(os.path.join(ROOT, f), encoding="utf-8").read()
    for pat in CALLS:
        for m in re.finditer(pat, src):
            s = m.group(1).encode().decode("unicode_escape").encode("latin-1").decode("utf-8")
            if not SKIP.match(s) and re.search(r"[A-Za-z]", s):
                out.add(s)
# tables
rules = open(os.path.join(ROOT, "core/rules.gd"), encoding="utf-8").read()
for tbl in ["PET_NAMES", "CLASS_NAMES", "CURSES"]:
    body = re.search(tbl + r" := \{(.*?)\}", rules, re.S).group(1)
    out.update(re.findall(r'"[a-z_]+": "([^"]+)"', body))
out.add(re.search(r'const GOLD_RULES := "([^"]+)"', rules).group(1))
main = open(os.path.join(ROOT, "ui/main.gd"), encoding="utf-8").read()
for tbl in ["SEAT_TYPES", "KIND_TAGS"]:
    body = re.search(tbl + r" := [\[\{](.*?)[\]\}]\n", main, re.S).group(1)
    out.update(v for v in re.findall(LIT, body) if re.search(r"[A-Z]", v))
how = re.search(r"const HOW_TO := \[(.*?)\n\]", main, re.S).group(1)
out.update(v for v in re.findall(LIT, how) if v)
out.update(["easy", "normal", "hard", " wild", " done", "unused rolls", "end of turn", "Curse", "a curse", "HERO_TITLE", "Hero"])
out = sorted(x for x in out if x not in ("Rules.GOLD_RULES",))
path = os.path.join(ROOT, "i18n", "source_en.json")
json.dump(out, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(len(out), "strings ->", os.path.normpath(path))
