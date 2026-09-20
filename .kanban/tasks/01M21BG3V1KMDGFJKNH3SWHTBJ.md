---
comments:
- actor: claude-code
  id: 01m2tnmvx348nv6wsmv5cbt9sc
  text: |-
    ### decision — ACP version in the README
    The kit speaks only ACP v2 (`SupportedProtocolVersions`, `Docs/decisions/acp-version.md`). All agents that are available now (Claude Code, Codex, Gemini, Zed) speak v1, so `ACPThreadSource` refuses them. The user decided to stay v2 only. The README must say this limit clearly, and it must say that the demo uses the in-memory agent.
  timestamp: 2026-09-18T16:29:58.051467+00:00
- actor: claude-code
  id: 01m2zgzg3968n7fpq34aehs57m
  text: |-
    ### finish iteration 1 — findings
    - implement: README.md, Package.swift (ReadmeSnippetsTests target at Examples/ReadmeSnippets), Scripts/extract-readme-snippets.sh, Scripts/check-readme.sh, four snippets in Examples/ReadmeSnippets/Snippets/, ReadmeSnippets.swift, ReadmeSnippetTests.swift and ReadmeCoverageTests.swift in PackageStructureTests.
    - test: `swift test` green. AgentViewKitTests 1284, AgentViewKitACPTests 120, AgentViewKitRouterTests 74, AgentViewKitFoundationModelsTests 59, PackageStructureTests 42 (was 23), ReadmeSnippetsTests 1. `Scripts/check-readme.sh` exit 0. `Scripts/test-examples.sh` 4 demo UI tests passed.
    - commit: 5a870e9 docs(readme): add the README with compiled snippets, the §9 coverage test, and the README gate (^3swhtbj).
    - review: 2 findings, both `swift/immutability` in Tests/PackageStructureTests/ReadmeSnippets.swift (mutable accumulators in `swiftBlocks`). Recorded in the description. Fix in iteration 2.
  timestamp: 2026-09-20T13:44:35.689490+00:00
- actor: claude-code
  id: 01m2zh4c2v632gc88j98tzqd00
  text: |-
    ### finish iteration 2 — clean
    - implement: removed the mutable accumulators in Tests/PackageStructureTests/ReadmeSnippets.swift (`swiftBlocks` with `reduce(into:)`, `snippetFiles` with a `map` into `Dictionary(uniqueKeysWithValues:)`).
    - test: `swift test` green. AgentViewKitTests 1284, AgentViewKitACPTests 120, AgentViewKitRouterTests 74, AgentViewKitFoundationModelsTests 59, PackageStructureTests 42, ReadmeSnippetsTests 1. No new warnings.
    - commit: 9547775 refactor(tests): build the README snippet scan and the file map without mutable accumulators (^3swhtbj).
    - review: `review sha HEAD~1..HEAD` zero findings. Both prior items checked. Task to done.
  timestamp: 2026-09-20T13:47:15.419744+00:00
depends_on:
- 01M21ARQVH6HRNAWTP8NY9E8RR
position_column: done
position_ordinal: cf80
title: README and compiled README snippets (plan §1, §9)
---
## What
Create `README.md` at the repo root and `Examples/ReadmeSnippets/` compiled by a test, the EditorKit pattern (`../EditorKit/Examples/ReadmeSnippets`).

- `README.md`: install (branch `main` until a tag), a 60-second quick start for each source (ACP, FoundationModels, Router), the component list from plan.md §9 with one line each, the override modifiers from §3.6, and a link to `plan.md`.
- Every code block in the README marked `// readme:compile` is extracted into `Examples/ReadmeSnippets/Snippets/` by `Scripts/extract-readme-snippets.sh` and compiled by the `ReadmeSnippetsTests` target.
- `Scripts/check-readme.sh` runs the extraction and fails when a snippet does not compile or when the README and the extracted files differ.

## Acceptance Criteria
- [x] `Scripts/check-readme.sh` exits 0.
- [x] Every component in plan.md §9 appears in the README list (a test compares the two lists).

## Tests
- [x] `Tests/ReadmeSnippetsTests`: compiles the snippets. The target is at `Examples/ReadmeSnippets` (the EditorKit pattern), with `Snippets/` for the extracted files.
- [x] `Tests/PackageStructureTests/ReadmeCoverageTests.swift`: the §9 list match.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-20 08:37)

> Scope: `review sha HEAD~1..HEAD` (5a870e9). 11 file(s) reviewed, 3 not reviewed (`.kanban/` by the ignore rule, `README.md` with no validator).

- [x] `Tests/PackageStructureTests/ReadmeSnippets.swift:48` `swift/immutability` — Collection is built with a mutable `var` accumulator rather than `map` or `compactMap`. The accumulator is mutable for the whole loop, forcing readers to trace every line of the body to understand the final result. Rewrite using functional operations like `map`, `filter`, or `reduce` to make the transformation explicit and immutable from the start. Fixed in 9547775: `swiftBlocks` folds the lines with `reduce(into:)`.
- [x] `Tests/PackageStructureTests/ReadmeSnippets.swift:49` `swift/immutability` — Collection is built with a mutable `var` accumulator rather than `map` or `compactMap`. The accumulator is mutable for the whole loop, forcing readers to trace every line of the body to understand the final result. Rewrite using functional operations to make the transformation explicit and immutable from the start. Fixed in 9547775. The same cause in `snippetFiles` is also removed: the dictionary comes from a `map`.

## Review Findings (2026-09-20 08:44)

> Scope: `review sha HEAD~1..HEAD` (9547775). 1 file reviewed, 2 not reviewed (`.kanban/` by the ignore rule). Zero findings.