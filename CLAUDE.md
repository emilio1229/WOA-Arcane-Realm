# Collaboration notes for Claude

This repository is the dedicated, standalone home for the Arcane Realm game and test builds.

## Before changing code

1. Read `README.md` and `docs/PROTOTYPE_BRIEF.md`.
2. Inspect the current files and recent history before editing.
3. Keep all work inside this repository. The WOA website and event-bot repositories are out of scope.
4. Do not infer engine, platform, controls, mechanics, art direction, or acceptance criteria. They are not specified in the current project notes. If a needed decision is unresolved, record it and ask the user rather than silently making it foundational.

## Change practices

- Preserve existing files and behavior. Make focused, additive changes.
- Avoid destructive cleanup, broad rewrites, and unrelated dependencies.
- Keep setup, build, and test instructions current when tooling is introduced.
- For each change, summarize what changed, relevant assumptions, and how a person can try it.
- Do not add generated builds, caches, credentials, or private assets to version control.
- If you introduce a prototype decision, update `docs/PROTOTYPE_BRIEF.md` so the next collaborator has the same context.
