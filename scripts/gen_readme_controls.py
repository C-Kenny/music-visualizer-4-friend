#!/usr/bin/env python3
"""
gen_readme_controls.py - regenerates the "Keyboard" subsection of README.md's
Controls section from HelpOverlay.pde's `lines` array - the SAME array shown
in-app when a user presses `?`. One source of truth for hotkeys instead of
two hand-maintained lists that inevitably drift apart.

Usage:
    scripts/gen_readme_controls.py            # regenerate README.md
    scripts/gen_readme_controls.py --check    # exit 1 if README.md is stale

If you add/change a hotkey, edit HelpOverlay.pde's `lines` array (it's what
players actually see in-app) and re-run this script - don't hand-edit the
generated block in README.md directly, it'll just get overwritten.

Format contract with HelpOverlay.pde: each entry is "KEY\tDESCRIPTION"; a
line with an empty description (no content after \\t, or no \\t at all) is a
section header; a bare "" entry is a section separator. This mirrors exactly
how HelpOverlay.draw() itself distinguishes headers from rows.
"""
import ast
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
HELP_PDE = REPO_ROOT / "Music_Visualizer_CK/src/core/HelpOverlay.pde"
README = REPO_ROOT / "README.md"

BEGIN = "<!-- BEGIN GENERATED KEYBOARD CONTROLS (scripts/gen_readme_controls.py) -->"
END = "<!-- END GENERATED KEYBOARD CONTROLS -->"


def parse_help_lines():
    text = HELP_PDE.read_text()
    m = re.search(r"String\[\] lines = \{(.*?)\};", text, re.S)
    if not m:
        raise SystemExit("Could not find `String[] lines = {...}` in " + str(HELP_PDE))
    entries = []
    for lit in re.finditer(r'"((?:[^"\\]|\\.)*)"', m.group(1)):
        entries.append(ast.literal_eval('"' + lit.group(1) + '"'))
    return entries


def key_md(raw):
    """Wrap each key token in backticks: 'g  G' -> '`g` / `G`', 'F6 / F7' unchanged shape."""
    tokens = [t for t in re.split(r"\s*/\s*|\s{2,}", raw.strip()) if t]
    def wrap(t):
        # A literal backtick can't be wrapped in single backticks (would
        # start a code fence) - markdown's escape is double-backticks with
        # padding spaces: `` ` ``
        if t == "`":
            return "`` ` ``"
        # GFM tables require pipes escaped even inside a code span.
        return f"`{t.replace(chr(124), chr(92) + chr(124))}`"
    return " / ".join(wrap(t) for t in tokens)


def build_sections():
    """Returns [(title, [(key_md, description), ...]), ...]."""
    entries = parse_help_lines()
    sections = []
    title, rows = None, []
    for entry in entries:
        if entry == "":
            if title is not None:
                sections.append((title, rows))
            title, rows = None, []
            continue
        if "\t" not in entry:
            continue
        key, desc = entry.split("\t", 1)
        if desc == "":
            title = key
        else:
            rows.append((key_md(key), desc))
    if title is not None:
        sections.append((title, rows))
    return sections


def build_block():
    lines = [BEGIN]
    for title, rows in build_sections():
        lines.append("")
        lines.append(f"**{title.title()}**")
        lines.append("")
        lines.append("| Key | Action |")
        lines.append("|-----|--------|")
        for key, desc in rows:
            lines.append(f"| {key} | {desc} |")
    lines.append("")
    lines.append(END)
    return "\n".join(lines)


def splice(readme_text, block):
    pattern = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END), re.S)
    if not pattern.search(readme_text):
        raise SystemExit(
            f"Could not find {BEGIN} ... {END} markers in README.md - "
            "add them around the Keyboard subsection first."
        )
    return pattern.sub(block, readme_text)


def main():
    check = "--check" in sys.argv
    current = README.read_text()
    block = build_block()
    generated = splice(current, block)

    if check:
        if current != generated:
            import difflib
            diff = difflib.unified_diff(
                current.splitlines(keepends=True),
                generated.splitlines(keepends=True),
                fromfile="README.md (checked in)",
                tofile="README.md (generated)",
            )
            sys.stdout.writelines(diff)
            print(
                "\nREADME.md's keyboard controls are stale relative to "
                "HelpOverlay.pde - run scripts/gen_readme_controls.py and "
                "commit the result.",
                file=sys.stderr,
            )
            sys.exit(1)
        print("README.md keyboard controls are up to date.")
        return

    README.write_text(generated)
    print(f"Wrote {README.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()
