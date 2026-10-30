---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m66fnfcc6gm5gjcc4xq2bm64
  text: |-
    ### implement — changed
    - evidence: wt/style-rules d29ba0b (delete 253 source/doc-scan @Test decls: PackageStructureTests 225, ReadmeSnippetsTests 1, AVK 27 incl. 10 trimmed from ProtocolVersion/AttachmentResolution/PermissionPresentation/ComposerProminentAction; PackageFileSupport, README gate scripts+CI job, docs scrubbed) and 8a56034 (EditorKit d2b9ea0: ProgressIndicatorStop gone, KeyWindowGate comments, AgentViewKitTestSupport re-exports EditorTestSupport, generic helper copies replaced by EditorTestSupport's, TemporaryDirectory→TemporaryFolder, SettableClock→FixedClock). Root `swift test`: 828 + 16 tests passed, 27 s wall. `swift build --package-path IntegrationTests --build-tests` succeeds, no own warnings. No test moved to .machineSerially (none reaches past its process). Stash "z9b8vjm partial" dropped.
    - next: /review
  timestamp: 2026-10-30T13:23:25.196466+00:00
position_column: done
position_ordinal: ffffff8380
title: 'No source-scan or doc-check tests: delete PackageStructureTests, ReadmeSnippetsTests and every source scan (user directive 2026-10-30)'
---
The user's directive, relayed by EditorKit (EditorKit ^gmkna2v deletes its StyleRules engines and scanners): no tests that scan source text or check docs. The user chose to delete all of them, including the manifest checks and the "no root test opens a window" guard.

- [ ] Delete the PackageStructureTests target and ReadmeSnippetsTests.
- [ ] Delete every *SourceScanTests file and any other test, in AgentViewKitTests, AgentViewKitStyleTests or IntegrationTests, that reads source or doc text.
- [ ] Delete the helpers that only those tests used: SwiftLiteralLexer, MarkdownTable/PackageFileSupport if nothing else uses them, and fixture folders.
- [ ] Package.swift, ARCHITECTURE.md, README and plan.md no longer mention them.
- [ ] Root swift test is green and IntegrationTests builds.

This replaces ^k4qzae's StyleRules adoption. The stash "z9b8vjm partial" is dropped.