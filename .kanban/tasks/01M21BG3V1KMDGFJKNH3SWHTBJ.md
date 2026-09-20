---
comments:
- actor: claude-code
  id: 01m2tnmvx348nv6wsmv5cbt9sc
  text: |-
    ### decision — ACP version in the README
    The kit speaks only ACP v2 (`SupportedProtocolVersions`, `Docs/decisions/acp-version.md`). All agents that are available now (Claude Code, Codex, Gemini, Zed) speak v1, so `ACPThreadSource` refuses them. The user decided to stay v2 only. The README must say this limit clearly, and it must say that the demo uses the in-memory agent.
  timestamp: 2026-09-18T16:29:58.051467+00:00
depends_on:
- 01M21ARQVH6HRNAWTP8NY9E8RR
position_column: doing
position_ordinal: '80'
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