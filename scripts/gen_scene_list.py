#!/usr/bin/env python3
"""
gen_scene_list.py - regenerates documentation/scene_list.md from the actual
source of truth (SceneIds.pde, the scenes[] instantiation block, and
SCENE_ORDER) instead of relying on someone remembering to hand-edit prose
every time a scene is added, renamed, or reordered.

Usage:
    scripts/gen_scene_list.py            # regenerate the file
    scripts/gen_scene_list.py --check    # exit 1 if the checked-in file is
                                          # stale (for CI), print a diff

Sources parsed (see comments inline for exact patterns expected):
  Music_Visualizer_CK/src/core/SceneIds.pde   - SCENE_X = N constants
  Music_Visualizer_CK/Music_Visualizer_CK.pde - scenes[N] = new ClassName(...)
                                                  and the SCENE_ORDER array
  Music_Visualizer_CK/src/scenes/**/*.pde     - first ~15 lines of each
                                                  scene file, scanned for a
                                                  "documentation/*.md" link
                                                  to surface as a "See:" note

If you reorganize SCENE_ORDER's comment style or the scenes[] block's
formatting, update the regexes below rather than hand-editing the generated
doc - the whole point is that scene_list.md should never need a human touch.
"""
import glob
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SKETCH = REPO_ROOT / "Music_Visualizer_CK"
MAIN_PDE = SKETCH / "Music_Visualizer_CK.pde"
IDS_PDE = SKETCH / "src/core/SceneIds.pde"
OUT_PATH = REPO_ROOT / "documentation/scene_list.md"

DOC_LINK_RE = re.compile(r"documentation/[\w./-]+\.md")
HOTKEY_RE = re.compile(r"hotkey-only\s*\('(\w)'\)")


def parse_scene_ids():
    text = IDS_PDE.read_text()
    ids = {}  # const name -> state number
    for m in re.finditer(r"static final int (SCENE_\w+)\s*=\s*(\d+);", text):
        ids[m.group(1)] = int(m.group(2))
    return ids


def parse_class_map():
    text = MAIN_PDE.read_text()
    classes = {}  # state number -> class name
    for m in re.finditer(r"scenes\[(\d+)\]\s*=\s*new (\w+)\(", text):
        classes[int(m.group(1))] = m.group(2)
    return classes


def parse_scene_order():
    """Returns (active_order: [const_name], notes: {const_name: reason_or_None})."""
    text = MAIN_PDE.read_text()
    block = re.search(r"final int\[\] SCENE_ORDER = \{(.*?)\};", text, re.S)
    if not block:
        raise SystemExit("Could not find SCENE_ORDER block in " + str(MAIN_PDE))

    active, notes = [], {}
    for raw in block.group(1).splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("//"):
            content = line[2:].strip()
            m = re.match(r"(SCENE_\w+)\s*(.*)", content)
            if not m:
                continue
            const, rest = m.group(1), m.group(2)
            rest = rest.lstrip(",").strip()
            rest = re.sub(r"^//\s*", "", rest)
            rest = re.sub(r"^-\s*", "", rest)
            notes[const] = rest or None
        else:
            m = re.match(r"(SCENE_\w+),?", line)
            if m:
                active.append(m.group(1))
    return active, notes


def find_scene_file(class_name):
    for pattern in (
        f"src/scenes/{class_name}.pde",
        f"src/scenes/games/{class_name}.pde",
        f"{class_name}.pde",
    ):
        p = SKETCH / pattern
        if p.exists():
            return p
    hits = glob.glob(str(SKETCH / "**" / f"{class_name}.pde"), recursive=True)
    return Path(hits[0]) if hits else None


def find_doc_link(class_name):
    path = find_scene_file(class_name)
    if not path:
        return None
    head = "\n".join(path.read_text().splitlines()[:15])
    m = DOC_LINK_RE.search(head)
    return m.group(0) if m else None


def display_name(const):
    words = const[len("SCENE_"):].split("_")
    fixups = {"3d": "3D", "tt": "TT", "fft": "FFT", "rip": "RIP"}
    out = []
    for w in words:
        lw = w.lower()
        out.append(fixups.get(lw, w.capitalize()))
    return " ".join(out)


def rel_file(class_name):
    path = find_scene_file(class_name)
    if not path:
        return f"`{class_name}.pde` (not found)"
    return f"`{path.relative_to(SKETCH)}`" if path.parent != SKETCH / "src/scenes" else f"`{path.name}`"


def build_doc():
    ids = parse_scene_ids()
    classes = parse_class_map()
    active, order_notes = parse_scene_order()
    active_set = set(active)

    hotkey_only = {}  # const -> key
    for const, note in order_notes.items():
        if not note:
            continue
        m = HOTKEY_RE.search(note)
        if m:
            hotkey_only[const] = m.group(1)

    lines = []
    lines.append("# Scene List")
    lines.append("")
    lines.append(
        "Every scene has a fixed **state number** (its index in the `scenes[]` array, "
        "set once in `setup()` and never changed). Which scenes are actually reachable "
        "day-to-day is a separate list: `SCENE_ORDER[]` in `Music_Visualizer_CK.pde` "
        f"picks {len(active)} of the {len(ids)} total scenes as \"the rotation.\""
    )
    lines.append("")
    lines.append(
        "- **LB / RB** (controller) and **`<` / `>`** (keyboard) step through "
        "`SCENE_ORDER` - previous/next in that list, not by state number."
    )
    lines.append(
        "- **Number keys `1`-`9`, `0`** jump straight to `SCENE_ORDER[0..9]` - i.e. "
        "only the *first 10 entries* of the rotation get a direct number-key slot. "
        "The remaining rotation scenes (and anything outside the rotation entirely) "
        "are reached via **`Tab`** (visual scene picker), LB/RB cycling, or "
        "`.devscene` (accepts a state number or a scene class name - see the "
        "[README](../README.md#dev-overrides))."
    )
    if hotkey_only:
        lines.append(
            "- Some scenes are **hotkey-only** - reachable by a dedicated key, not "
            "part of the rotation at all (see below)."
        )
    lines.append(
        "- The rest exist in code but aren't wired into `SCENE_ORDER` right now - "
        "reachable via `.devscene` or by editing `SCENE_ORDER` yourself."
    )
    lines.append("")
    lines.append(
        "**This file is generated.** Run `scripts/gen_scene_list.py` after adding, "
        "renaming, or reordering a scene rather than hand-editing the tables below - "
        "CI checks this file matches freshly-generated output "
        "(`scripts/gen_scene_list.py --check`)."
    )
    lines.append("")

    lines.append("## Active rotation (`SCENE_ORDER`, in cycling order)")
    lines.append("")
    lines.append("| Key | Pos. | State | Scene | File |")
    lines.append("|-----|------|-------|-------|------|")
    for i, const in enumerate(active):
        state = ids[const]
        cls = classes.get(state, "?")
        if i < 9:
            key = str(i + 1)
        elif i == 9:
            key = "0"
        else:
            key = "-"
        name = display_name(const)
        link = find_doc_link(cls)
        if link:
            # link is repo-root-relative ("documentation/x.md"); this file
            # already lives in documentation/, so strip that prefix.
            rel_link = link[len("documentation/"):]
            name += f" - see [{Path(link).name}]({rel_link})"
        lines.append(f"| {key} | {i} | {state} | {name} | {rel_file(cls)} |")
    lines.append("")
    lines.append(
        "(Position 9 in the table above is where the row for keyboard `0` sits - "
        "`SCENE_ORDER[9]`, not `SCENE_ORDER[0]`. Keys `1`-`9` map to positions "
        "`0`-`8`, and `0` maps to position `9`.)"
    )
    lines.append("")

    if hotkey_only:
        lines.append("## Hotkey-only scenes (not in the rotation)")
        lines.append("")
        lines.append("| Key | State | Scene | File |")
        lines.append("|-----|-------|-------|------|")
        for const, key in hotkey_only.items():
            state = ids[const]
            cls = classes.get(state, "?")
            lines.append(f"| `{key}` | {state} | {display_name(const)} | {rel_file(cls)} |")
        lines.append("")

    excluded = [
        (const, state) for const, state in sorted(ids.items(), key=lambda kv: kv[1])
        if const not in active_set and const not in hotkey_only
    ]
    lines.append("## Not currently in the rotation")
    lines.append("")
    lines.append(
        "Exists in code, has a state number, loads fine - just not wired into "
        "`SCENE_ORDER`. Reach any of these with `.devscene` (name or number) or "
        "by adding the constant to `SCENE_ORDER` yourself. Where the code comment "
        "next to a scene's (commented-out) `SCENE_ORDER` entry gives a reason, "
        "it's shown; most others simply predate the current rotation and haven't "
        "been revisited."
    )
    lines.append("")
    lines.append("| State | Scene | File | Note |")
    lines.append("|-------|-------|------|------|")
    for const, state in excluded:
        cls = classes.get(state, "?")
        note = order_notes.get(const) or ""
        lines.append(f"| {state} | {display_name(const)} | {rel_file(cls)} | {note} |")
    lines.append("")

    lines.append("## Scene count")
    lines.append("")
    lines.append(
        f"{len(ids)} total (`SCENE_COUNT` in `Music_Visualizer_CK.pde`), "
        f"{len(active)} in the active rotation, {len(hotkey_only)} hotkey-only, "
        f"{len(excluded)} not currently wired in. Regenerate this file "
        "(`scripts/gen_scene_list.py`) rather than editing these numbers by hand."
    )
    lines.append("")

    return "\n".join(lines)


def main():
    check = "--check" in sys.argv
    generated = build_doc()

    if check:
        current = OUT_PATH.read_text() if OUT_PATH.exists() else ""
        if current != generated:
            import difflib
            diff = difflib.unified_diff(
                current.splitlines(keepends=True),
                generated.splitlines(keepends=True),
                fromfile="documentation/scene_list.md (checked in)",
                tofile="documentation/scene_list.md (generated)",
            )
            sys.stdout.writelines(diff)
            print(
                "\ndocumentation/scene_list.md is stale - run "
                "scripts/gen_scene_list.py and commit the result.",
                file=sys.stderr,
            )
            sys.exit(1)
        print("documentation/scene_list.md is up to date.")
        return

    OUT_PATH.write_text(generated)
    print(f"Wrote {OUT_PATH.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()
