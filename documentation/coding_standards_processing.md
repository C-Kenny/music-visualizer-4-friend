# Processing Code Standards

This document defines readability and naming conventions for the Processing 4 visualizer code in `Music_Visualizer_CK/*.pde`.

## Goals

- Make scene logic easy to read and maintain.
- Keep naming consistent across all scenes.
- Preserve artistic math clarity where concise symbols are better.
- Improve quality incrementally without risky mass rewrites.

## Naming Conventions

- Use `camelCase` for methods, local variables, and fields.
- Use `PascalCase` for class names.
- Use `UPPER_SNAKE_CASE` for constants.
- Avoid abbreviations when they are not math-specific.
- Prefer identifier names with at least 5 characters where practical.

### Allowed short names

Short names are acceptable in constrained math/graphics loops:

- Loop counters: `i`, `j`, `k`
- Coordinates and vectors: `x`, `y`, `z`, `dx`, `dy`, `cx`, `cy`
- Channels and common color components: `r`, `g`, `b`, `a`
- Common geometric temporaries: `t`, `u`, `v`

Outside these cases, use descriptive names.

## Layout and Formatting

- Use spaces (no tabs) for indentation.
- Keep one logical operation per line when possible.
- Prefer short helper methods over long monolithic blocks.
- Keep side-effect-heavy logic separated from drawing logic.
- Add comments only for non-obvious intent, not obvious mechanics.

## Processing-Specific Guidelines

- Keep `drawScene()` focused on orchestration; move detailed behavior into helpers.
- Avoid per-frame allocation in hot loops where possible.
- Use `lerp()` for smoothing reactive visual values.
- Reset global state that can leak between scenes (e.g. `blendMode(BLEND)`).

## Incremental Refactor Policy

- Do not perform large rename sweeps across all scenes in one change.
- Tidy files when touching them for feature/bug work.
- Preserve behavior first; style improvements should be behavior-neutral.

## Quality Script

Use the audit helper to spot naming and style drift:

```bash
./scripts/pde_style_audit.sh
```

This script reports probable issues (warnings), not hard failures.
