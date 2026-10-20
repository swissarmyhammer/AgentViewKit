---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5dgjdw51byaj2475t2tm1be
  text: |-
    Research done.
    - Sources has 75 public `View` types: 74 in `Sources/AgentViewKit` and `GalleryColumns` in `Sources/DemoSupport`. `HostedViewHarness` is a class with a `View` generic constraint, not a view. No file has a `#Preview` now.
    - FoundationModelsACPClient main gives `SessionModel.preview(...)`, `SessionModel.previewSample`, `ConnectionModel.preview(...)`, `ConnectionModel.previewSample`, `PreviewTranscriptItem` (user, agent, thought, toolCall, plan, terminal, error, update) and public `apply(_:)`.
    - Item views take entry objects (`ThoughtEntry`, `ToolCallEntry` and so on). A preview gets them from `SessionModel.preview(transcript:).transcript`.
    - Views that read `\.sessionModel` (ConnectionsView, DefaultPromptAccessory, MessageActions) need `.environment(\.sessionModel, session)` in the preview.
    - The package structure scans (SymbolNameTests, FixedColorTests, FixedCodeFontTests and others) read all of `Sources`, so preview code must obey them too: symbol names come from `SharedSymbol`, no fixed system colors.
    - Validators: no force unwrap in Sources, no unnamed numeric literal in a call argument (swiftlint `no_magic_numbers`), no duplicated blocks. Plan: one internal preview fixture file for shared values, and a structure test `PreviewCoverageTests`.
  timestamp: 2026-10-20T20:38:13.125079+00:00
- actor: claude-code
  id: 01m5dhx90weadtz6jxzzv44p6s
  text: |-
    Implementation landed for 72 of 75 public views. BLOCKER for 3 views.

    Done:
    - New structure test `Tests/PackageStructureTests/PreviewCoverageTests.swift`: each public `View` type in `Sources` must have a `#Preview` in its file whose body names the type. It also scans `Sources/DemoSupport` (GalleryColumns has a preview).
    - New internal `Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift` with value-built fixtures (entries from `SessionModel.preview`, elicitation fields, attachments, config options, usage, MCP servers, citations), and unit tests in `Tests/AgentViewKitTests/Infrastructure/PreviewFixturesTests.swift` (10 tests).
    - A `#Preview` in the file of each other public view: thread and items, human in the loop and elicitation fields/layout/footer, input and composer, sessions, activity, usage and the rest. `swift build` builds all previews.

    Blocker (3 views have no preview): `ElicitationView`, `ElicitationHeader` (both in `Elicitation/ElicitationView.swift`) and `ElicitationURLConsentView`. Each one needs a `PendingElicitation`. Its initializer is internal in FoundationModelsACPClient, and `SessionModel.preview(...)` makes pending permissions only. No public value path makes a pending elicitation. The FoundationModelsACPClient card 01M5DB8WPNEDC652CBFJEBHKM3 ("Preview: a public way to make a pending elicitation on a preview SessionModel") holds this gap, and it needs an API agreement first. What I did not do: build a live in-process connection in the kit that sends `elicitation/create`. That copies the scripted agent of DemoSupport and is not "a model built from values".

    Effect: `PreviewCoverageTests.eachPublicViewOfTheSourcesHasAPreviewInItsFile` fails and names only these 3 views. A person must decide: land the upstream API, or change the card scope for the 3 views.

    Note: `SessionStreamBanner` has a preview, but its states (closed, replaying, missed updates) have no public value path either, so the preview shows the empty state of `ConnectionModel.previewSample`.
  timestamp: 2026-10-20T21:01:37.180076+00:00
- actor: claude-code
  id: 01m5dhxg9k0x86wacsvq5ne845
  text: |-
    ### implement — stuck
    - evidence: 69 files (66 changed, 3 new: Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift, Tests/AgentViewKitTests/Infrastructure/PreviewFixturesTests.swift, Tests/PackageStructureTests/PreviewCoverageTests.swift). `swift test`: AgentViewKitTests 1373 tests in 161 suites passed with the 2 known issues; PackageStructureTests 134 tests in 18 suites with 1 failure, `PreviewCoverageTests.eachPublicViewOfTheSourcesHasAPreviewInItsFile`, which names ElicitationView, ElicitationHeader and ElicitationURLConsentView.
    - next: a person decides the gap of the 3 elicitation views (FoundationModelsACPClient card 01M5DB8WPNEDC652CBFJEBHKM3: no public way to make a PendingElicitation). Then add their previews; the structure test passes with no other change.
  timestamp: 2026-10-20T21:01:44.627122+00:00
- actor: claude-code
  id: 01m5dj70086seaasww69k4v9b5
  text: |-
    ### implement — changed
    - The blocker is gone: FoundationModelsACPClient main 1adaf09 (^jebhkm3) adds `pendingElicitations:` to `SessionModel.preview` and `ConnectionModel.preview`. Ran `swift package update FoundationModelsACPClient` and `Examples/AgentViewKitDemo/Scripts/generate_xcodeproj.rb` (Package.resolved and the .xcodeproj are git-ignored, so git shows no change for them).
    - New fixtures in PreviewFixtures: `formElicitation` (3 fields, with `agentPath` and `source` in `_meta`, so the "who asks" line shows), `urlElicitation`, `elicitationSession`, with 3 new unit tests.
    - New previews: `ElicitationView` ("Form"), `ElicitationHeader` ("Form header"), `ElicitationURLConsentView` ("URL consent"). Each public view now has a preview.
    - `SessionStreamBanner`: the new API gives no value path for the closed, replay or missed-updates state, so its preview is not changed.
    - evidence: 71 files (68 changed, 3 new). `swift test`: PackageStructureTests 134 tests in 18 suites passed; AgentViewKitTests 1376 tests in 161 suites passed with the 2 known issues; ReadmeSnippetsTests 1 test passed; only the mlx bundle warning, as before.
    - next: /review.
  timestamp: 2026-10-20T21:06:55.624542+00:00
- actor: claude-code
  id: 01m5djaw2tn07s9116r8hxb9gt
  text: |-
    ### test - green
    - evidence: swift test - 1376 tests in 161 suites passed, 0 failed, 0 skipped, 2 known issues (known before). The only warning is the mlx bundle build warning (known before).
    - next: review
  timestamp: 2026-10-20T21:09:02.682529+00:00
depends_on:
- 01M5D07DY0EJVKY1G21Y1E9RMY
position_column: doing
position_ordinal: '80'
title: 'AVK-7f #Preview for each public view'
---
Design: AVK-7, D105 (h). Step 5 work.

AgentViewKit has no `#Preview` (about 72 public views). Add one `#Preview` for each public view, with a model built from values (`SessionModel.preview` / `previewSample`, and `apply(_:)` from the AVK-7a card for states that need updates). Put each preview in the file of its view.

Split the work into parts that can each be one commit: thread and items; human in the loop and elicitation; input and composer; sessions, activity, usage and the rest.

Acceptance: `swift build` builds all previews; a package structure test checks that each public `View` type in Sources has a `#Preview` in its file. #avk-7