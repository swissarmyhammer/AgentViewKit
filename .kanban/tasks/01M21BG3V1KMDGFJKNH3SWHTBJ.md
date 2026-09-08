---
depends_on:
- 01M21ARQVH6HRNAWTP8NY9E8RR
position_column: todo
position_ordinal: bc80
title: README and compiled README snippets (plan §1, §9)
---
## What
Create `README.md` at the repo root and `Examples/ReadmeSnippets/` compiled by a test, the EditorKit pattern (`../EditorKit/Examples/ReadmeSnippets`).

- `README.md`: install (branch `main` until a tag), a 60-second quick start for each source (ACP, FoundationModels, Router), the component list from plan.md §9 with one line each, the override modifiers from §3.6, and a link to `plan.md`.
- Every code block in the README marked `// readme:compile` is extracted into `Examples/ReadmeSnippets/Snippets/` by `Scripts/extract-readme-snippets.sh` and compiled by the `ReadmeSnippetsTests` target.
- `Scripts/check-readme.sh` runs the extraction and fails when a snippet does not compile or when the README and the extracted files differ.

## Acceptance Criteria
- [ ] `Scripts/check-readme.sh` exits 0.
- [ ] Every component in plan.md §9 appears in the README list (a test compares the two lists).

## Tests
- [ ] `Tests/ReadmeSnippetsTests`: compiles the snippets.
- [ ] `Tests/PackageStructureTests/ReadmeCoverageTests.swift`: the §9 list match.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.