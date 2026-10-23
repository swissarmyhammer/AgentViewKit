---
assignees:
- claude-code
position_column: todo
position_ordinal: aa80
title: Use the InProcessAgent of FoundationModelsACPClient and remove the kit copy
---
Found by the implement step of ^66has33 (2026-10-23).

FoundationModelsACPClient 6395cca (2026-10-23) "feat(client): move InProcessAgent from AgentViewKit into FoundationModelsACPClient" adds `public enum InProcessAgent` to the client. The kit still has `Sources/AgentViewKit/ACP/InProcessAgent.swift`. With the client at main, `swift build --build-tests` fails:

- `Sources/DemoSupport/DemoAgent.swift`: error: ambiguous use of 'InProcessAgent' (candidates in AgentViewKit and in FoundationModelsACPClient).
- `Examples/ReadmeSnippets/Snippets/InProcessQuickStart.swift`: the same error.

Package.resolved is not tracked (8684838), so each new resolve gets the client main and the build fails. The workaround for ^66has33 was a local pin of the client to 04197c9 (6395cca^) in the untracked Package.resolved.

To do: remove the kit copy of InProcessAgent and its tests that the client now owns, use the client type in DemoSupport, the README snippets and the README, and update ARCHITECTURE/plan text that names the kit copy. Do not keep an alias (ARCHITECTURE.md: no backward compatibility).

Acceptance: with all packages at main (`swift package update`), `swift build --build-tests` and `swift test` are green. #bug