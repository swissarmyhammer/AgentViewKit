---
depends_on:
- 01M21ARQVH6HRNAWTP8NY9E8RR
- 01M21AGTHBZSXFCZHZE5A7FQWQ
- 01M21BF3845VTY0NRCX33FXW2B
position_column: doing
position_ordinal: '80'
title: Demo app FoundationModels tab, availability gate, and fake-model launch argument (plan §1)
---
## What
Add the "FoundationModels" tab to `Examples/AgentViewKitDemo/`, per plan.md §1.

- The tab creates a `LanguageModelSession` on `SystemLanguageModel.default` with two sample tools (a clock and a word counter), binds `SessionThreadSource` and `SessionThreadActions`, and shows `AgentThreadView`, `PromptInputView`, `ContextUsageView`, and `ActivityTimeline`.
- Availability: the tab reads `SystemLanguageModel.default.availability`. When the model is unavailable, the tab shows the reason text and no composer.
- Launch argument `--fake-language-model`: the app binds the fake `LanguageModel` from the FoundationModels test target (moved into a shared `DemoSupport` module) so the end-to-end test runs on a machine without the model.

## Acceptance Criteria
- [ ] With `--fake-language-model`, a send of "hello" produces an assistant message from the scripted fake.
- [ ] Without the model, the tab shows the availability reason and no composer.

## Tests
- [ ] `Examples/AgentViewKitDemo/Tests/FoundationModelsTabEndToEndTests.swift`: the send flow through `XCUIApplication` with the launch argument; the unavailable case with a second launch argument `--force-model-unavailable`.
- [ ] `Scripts/test-examples.sh` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.