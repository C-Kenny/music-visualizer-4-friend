# Coding Standards

This repository uses a readability-first code style.

## Naming

- Use `camelCase` for variables and functions.
- Use `PascalCase` for class names.
- Use `UPPER_SNAKE_CASE` for constants.
- Avoid abbreviated names outside math-heavy code.
- Target identifier names with at least 5 characters where practical.

Math and graphics code can use short symbols (`x`, `y`, `i`, `j`, etc.) when that makes formulas easier to read.

## Layout and formatting

- Use 2-space indentation for JavaScript.
- Keep lines readable (target 100 characters).
- Prefer trailing commas in multiline arrays and objects.
- Keep related code grouped with short section comments.

## Tooling

- Formatter: Prettier
- Linting baseline: ESLint

Run these commands from repository root:

```bash
npm run format:web
npm run lint:web
```

Current scope focuses on web visualizer files:

- `web/config.js`
- `web/sketch.js`
- `web/scenes/scene_mandala.js`

## Incremental cleanup policy

This repository contains legacy visual-math code. Cleanups should be incremental:

1. Touch code in place while preserving behavior.
2. Rename unclear identifiers when editing nearby logic.
3. Keep visual tuning constants explicit and documented.
4. Avoid large mechanical rewrites without validation runs.
