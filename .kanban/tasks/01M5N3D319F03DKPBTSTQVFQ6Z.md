---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5n8wgcczaeta62aj68b6ean
  text: |-
    Research and implementation:
    - `swift package update` moved all packages to main. FoundationModelsACPClient is now at main 64c181d. Before the change, `swift build --build-tests` failed with "ambiguous use of 'InProcessAgent'" in Sources/DemoSupport/DemoAgent.swift (RED).
    - The client type `InProcessAgent` is `@MainActor` and has the same `makeConnection(serving:)` signature. Each kit caller already awaits it, so no caller changed.
    - The client has its own InProcessAgentTests with the same four behaviors (connected model, prompt round trip, agent close gives disconnected, disconnect gives endOfInput). Thus the kit test file is removed.
    - `AgentConnectionBox` (DemoSupport) had only one user: the removed kit test. It is removed as dead code.
    - Removed: Sources/AgentViewKit/ACP/InProcessAgent.swift, Tests/AgentViewKitTests/ACP/InProcessAgentTests.swift, Sources/DemoSupport/AgentConnectionBox.swift.
    - Docs changed: README.md (dependency list and the in-process section name the client), plan.md (two places), Docs/decisions/dependencies.md, Sources/DemoSupport/InMemoryDemoACPAgent.swift (doc link), Examples/AgentViewKitDemo/Scripts/generate_xcodeproj.rb (comment). ARCHITECTURE.md does not name the kit copy, so it did not change.
    - The root Package.resolved (untracked) is copied to the demo xcodeproj swiftpm folder. ResolvedPinsTests.theGeneratedDemoProjectPinsTheRootACPRevisions fails until that copy is done.
    - Note: the dump of validators was 750k characters. Only the rule headings were read, not each rule body.
  timestamp: 2026-10-23T20:57:50.220310+00:00
- actor: claude-code
  id: 01m5n8wm62n6xb5we3cwj3kzm7
  text: |-
    ### implement — changed
    - evidence: 3 files removed (Sources/AgentViewKit/ACP/InProcessAgent.swift, Sources/DemoSupport/AgentConnectionBox.swift, Tests/AgentViewKitTests/ACP/InProcessAgentTests.swift); 6 files edited (README.md, plan.md, Docs/decisions/dependencies.md, Sources/DemoSupport/InMemoryDemoACPAgent.swift, Examples/AgentViewKitDemo/Scripts/generate_xcodeproj.rb). `swift package update` (all at main, client 64c181d). `swift build --build-tests`: Build complete. `swift test`: 1 + 227 + 1710 tests passed (3 known issues that the tests expect). Demo: generate_xcodeproj.rb, then `xcodebuild -scheme AgentViewKitDemo build`: BUILD SUCCEEDED. The only build warning is the SwiftPM "missing creator for mutated node" of the mlx-swift_Cmlx bundle, which is not in the kit code.
    - next: /review
  timestamp: 2026-10-23T20:57:54.114142+00:00
- actor: claude-code
  id: 01m5n930hjhwy58vxmcp9k5wwx
  text: |-
    ### review — clean
    - evidence: review sha HEAD~1..HEAD (3c21612); counts: findings 0, confirmed 0, refuted 0, attempted 8, failed 0. No prior Review Findings sections. The engine could not read the Swift files that this change deleted (InProcessAgent.swift, AgentConnectionBox.swift, InProcessAgentTests.swift). This is correct, because the files do not exist. No validator matched README.md, plan.md and Docs/decisions/dependencies.md.
    - next: none. The task moved to done.
  timestamp: 2026-10-23T21:01:23.378609+00:00
- actor: claude-code
  id: 01m5n93bnfn4enz280566zn33h
  text: |-
    ### finish iteration 1 — clean
    - implement: changed — 3 files removed, 5 files edited
    - test: green — swift test, 1710 passed, 0 failed, 0 skipped
    - commit: 3c21612
    - review: clean — review sha HEAD~1..HEAD, 0 findings
  timestamp: 2026-10-23T21:01:34.767409+00:00
position_column: done
position_ordinal: ffffcb80
title: Use the InProcessAgent of FoundationModelsACPClient and remove the kit copy
---
Found by the implement step of ^66has33 (2026-10-23).

FoundationModelsACPClient 6395cca (2026-10-23) "feat(client): move InProcessAgent from AgentViewKit into FoundationModelsACPClient" adds `public enum InProcessAgent` to the client. The kit still has `Sources/AgentViewKit/ACP/InProcessAgent.swift`. With the client at main, `swift build --build-tests` fails:

- `Sources/DemoSupport/DemoAgent.swift`: error: ambiguous use of 'InProcessAgent' (candidates in AgentViewKit and in FoundationModelsACPClient).
- `Examples/ReadmeSnippets/Snippets/InProcessQuickStart.swift`: the same error.

Package.resolved is not tracked (8684838), so each new resolve gets the client main and the build fails. The workaround for ^66has33 was a local pin of the client to 04197c9 (6395cca^) in the untracked Package.resolved.

To do: remove the kit copy of InProcessAgent and its tests that the client now owns, use the client type in DemoSupport, the README snippets and the README, and update ARCHITECTURE/plan text that names the kit copy. Do not keep an alias (ARCHITECTURE.md: no backward compatibility).

Acceptance: with all packages at main (`swift package update`), `swift build --build-tests` and `swift test` are green. #bug