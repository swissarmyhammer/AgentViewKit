---
comments:
- actor: claude-code
  id: 01m2zfmg1xwd31x853pgp19hvd
  text: |-
    ### finish iteration 1 — done

    - implement: moved `FakeLanguageModel` into `DemoSupport`; added `ClockTool`, `WordCountTool`, `FoundationModelsDemoSession`, `FoundationModelsTabView`, the `DemoTab` selection in `DemoRootView`, and the `--fake-language-model` and `--force-model-unavailable` arguments (`DemoLaunchOptions.languageModel`); linked `AgentViewKitFoundationModels` in the demo project; shared the UI test helpers in `DemoTestValues.swift`.
    - test: `swift test` green — AgentViewKitTests 1284, AgentViewKitACPTests 120, AgentViewKitRouterTests 74, PackageStructureTests 23, AgentViewKitFoundationModelsTests 59 (48 + 11 new); `Scripts/test-examples.sh` green — 4 demo UI tests (2 + 2 new). No new warning; only the accepted mlx warning.
    - commit: `0805a6e` feat(demo): add the FoundationModels tab with the fake model and the availability gate (^c4c24yp). The `.kanban/` changes are in the same commit.
    - review: `review sha HEAD~1..HEAD` — 17 files reviewed, 0 findings. Clean.
  timestamp: 2026-09-20T13:21:06.621472+00:00
depends_on:
- 01M21ARQVH6HRNAWTP8NY9E8RR
- 01M21AGTHBZSXFCZHZE5A7FQWQ
- 01M21BF3845VTY0NRCX33FXW2B
position_column: done
position_ordinal: ce80
title: Demo app FoundationModels tab, availability gate, and fake-model launch argument (plan §1)
---
## What
Add the "FoundationModels" tab to `Examples/AgentViewKitDemo/`, per plan.md §1.

- The tab creates a `LanguageModelSession` on `SystemLanguageModel.default` with two sample tools (a clock and a word counter), binds `SessionThreadSource` and `SessionThreadActions`, and shows `AgentThreadView`, `PromptInputView`, `ContextUsageView`, and `ActivityTimeline`.
- Availability: the tab reads `SystemLanguageModel.default.availability`. When the model is unavailable, the tab shows the reason text and no composer.
- Launch argument `--fake-language-model`: the app binds the fake `LanguageModel` from the FoundationModels test target (moved into a shared `DemoSupport` module) so the end-to-end test runs on a machine without the model.

## Acceptance Criteria
- [x] With `--fake-language-model`, a send of "hello" produces an assistant message from the scripted fake.
- [x] Without the model, the tab shows the availability reason and no composer.

## Tests
- [x] `Examples/AgentViewKitDemo/Tests/FoundationModelsTabEndToEndTests.swift`: the send flow through `XCUIApplication` with the launch argument; the unavailable case with a second launch argument `--force-model-unavailable`.
- [x] `Scripts/test-examples.sh` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Decisions
- `DemoLaunchOptions.languageModel` is one enum (`system`, `fake`, `forcedUnavailable`), not two flags, so the two arguments cannot both be set. The last argument wins.
- Each of the two FoundationModels arguments also opens the app on the FoundationModels tab (`DemoLaunchOptions.initialTab`), so the UI test does not click the tab bar.
- The fake reply has no entry id. The SDK gives each reply a new id, so a second send does not repeat an id. The fake script has no tool call for that reason.
- `FakeLanguageModel` stays `internal` in `DemoSupport`. The demo app compiles the sources, and the tests use `@testable import DemoSupport`.
- The UI test finds the assistant message by the identifier prefix `assistant-message-`, and the activity timeline by its container identifier `activity-timeline` (the empty state of a `ContentUnavailableView` is not an element for XCUITest).

## Review Findings (2026-09-20 08:15)
Review of `0805a6e` (`review sha HEAD~1..HEAD`): 17 files reviewed, 0 findings. Nothing to fix.