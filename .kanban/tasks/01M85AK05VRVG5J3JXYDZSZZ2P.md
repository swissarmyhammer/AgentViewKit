---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m85bbnm9sd9dwmsj1phn400c
  text: |-
    Research and design:
    - The composer already has a submit hook: `.onComposerSubmit(_:)` with `ComposerSubmitResult.consumed`. While the hook runs, `PromptInputView` sets `isSubmitting`: the field is disabled, the accessory shows the progress mark, and `canSubmit` is false, so a second Return or Send does nothing. After `.consumed`, `apply` clears the text and the draft, and starts no prompt. The new option reuses this path. It makes no second composer.
    - `.threadComposer(placeholder:onSubmit:)` sets `\.threadComposerRoute`. `AgentThreadView` shows the slot when `AgentThreadLayout.showsComposer(for:hasHostComposer:)` is true. For a read-only session, `ThreadComposerRouting` sets `\.promptPlaceholder` and `\.composerSubmitHook` with `transformEnvironment`, so the identity of the composer does not change when the session becomes live while the closure runs. A live thread does not read the value.
    - `ThreadComposerRoute.submit` gives the plain text to the host one time and returns `.consumed`. A blank text gives `.cancel` and does not call the host.
    - A read-only root model has `canPrompt == true` and `isClosed == false`, so the composer is enabled. A mode change of a read-only model throws, so `DefaultPromptAccessory.showsModePicker(for:)` hides the picker for a read-only session.
    - The scope of a read-only thread still registers no `compose` verb. Return works (direct submit when `perform(.send)` is false), but Send Message and Focus Composer are not in the menus. New task ^namctv7 records this for a decision.
    - TDD notes: 7 of 14 new tests failed on stubs first. These passed on the stubs and guard behavior: blank text does not call the host, the text clears (the stub `.send` also clears; the consume test catches `.send`), the live-thread tests, the kit placeholder, and "no host composer shows no composer". The order test was added after the change.
    - IntegrationTests now links `ACPMarkdown` (for `SessionSnapshot` in the hosted test).
  timestamp: 2026-11-23T23:20:18.825547+00:00
- actor: claude-code
  id: 01m85bbw8gnpbbsbbev5s5ean6
  text: |-
    ### implement — changed
    - evidence: headless `swift test` in the root: 1704 tests in 191 suites and 59 tests in 12 suites pass, 0 failures, no code warnings. ThreadComposerTests: 15 tests (7 seen RED on stubs first). `swift build --build-tests` passes in IntegrationTests and in ScreenshotTests, no warnings.
    - files: Sources/AgentViewKit/Thread/ThreadComposer.swift (new), Sources/AgentViewKit/Thread/AgentThreadView.swift, Sources/AgentViewKit/Input/PromptInputView.swift, Sources/AgentViewKit/Input/DefaultPromptAccessory.swift, Tests/AgentViewKitTests/Thread/ThreadComposerTests.swift (new), IntegrationTests/Tests/IntegrationTests/Thread/ThreadComposerHostedTests.swift (new), IntegrationTests/Package.swift (ACPMarkdown product), ScreenshotTests/Tests/ScreenshotTests/SharedThreadFixtures.swift, ScreenshotTests/Tests/ScreenshotTests/HostedSnapshotTests.swift, ARCHITECTURE.md
    - not run (the screen is in use): `cd IntegrationTests && swift test --filter ThreadComposerHostedTests`; `HOME=<temp> swift test --package-path ScreenshotTests --filter theExternalThreadWithTheComposerOfTheHost` (image thread-external-composer-{light,dark}.png).
    - next: run the hosted test and the gallery when the screen is free, then /review.
  timestamp: 2026-11-23T23:20:25.616080+00:00
- actor: claude-code
  id: 01m85bjpfgg7mtdk0ax9m54qjr
  text: |-
    ### review — findings
    - evidence: `review sha HEAD~1..HEAD` (commit 5ff277d7): 1 finding (1 confirmed, 2 refuted). `IntegrationTests/Tests/IntegrationTests/Thread/ThreadComposerHostedTests.swift:99` `reuse/reuse`. The headless evidence (swift test 1704 + 59 pass; ThreadComposerTests 15, 7 failed on stubs first; builds clean) satisfies the boxes of the work items 1 to 4, the 3 acceptance criteria, and the first 2 test items. These boxes are ticked.
    - open: the reuse finding; the gallery screen thread-external-composer (written and built, not run); ThreadComposerHostedTests (3 tests, written and built, not run). The screen is in use, so no hosted test and no gallery ran.
    - next: move draftText(of:) to one shared helper in the IntegrationTests target and delete the copy, then run ThreadComposerHostedTests and the gallery screen when the screen is free, then /review again. The task stays in review.
  timestamp: 2026-11-23T23:24:09.072147+00:00
- actor: claude-code
  id: 01m85bmqm081e1vtf0gxvwsw83
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 11 files
    - test: green — swift test 1704 + 59; builds clean; hosted and gallery not run (screen in use)
    - commit: 5ff277d7
    - review: findings — IntegrationTests/Tests/IntegrationTests/Thread/ThreadComposerHostedTests.swift:99

    ### implement — changed
    - evidence: `ComposerHarness.draftText(of: SessionModel)` is the one helper. ThreadComposerHostedTests calls it, and its copy is removed. `ComposerDraftHostedTests.draftText(of: ScriptedSession)` is now a one-line call to it. IntegrationTests build complete.
    - open: ThreadComposerHostedTests (3) and the gallery screen thread-external-composer run on CI or when the screen is free.
  timestamp: 2026-11-23T23:25:15.776119+00:00
- actor: claude-code
  id: 01m85bq11r70tvm629d7xc21hj
  text: |-
    ### review — clean
    - evidence: `review sha HEAD~1..HEAD` (commit 9aea30e7): 0 findings, 0 confirmed, 0 refuted; 7 attempted, 0 failed. 3 files reviewed. The one prior finding (ThreadComposerHostedTests.swift:99 reuse/reuse) is checked.
    - next: The task stays in review. Two items are open: (1) the gallery screen of a read-only thread with this composer (thread-external-composer), and (2) the hosted test run of ThreadComposerHostedTests and the gallery run. Do these items on CI or when the screen is free. Then move the task to done.
  timestamp: 2026-11-23T23:26:30.968133+00:00
- actor: claude-code
  id: 01m86sc7hamdhqb1d9hg9r4b2q
  text: |-
    ### review — clean
    - evidence: No new review. The newest code range of this card is commit 9aea30e7, and it has a clean review record (`review sha HEAD~1..HEAD`: 0 findings, 0 confirmed, 0 refuted). Commit dbc80b63 changes only the comments of this card. The one prior finding (ThreadComposerHostedTests.swift:99 reuse/reuse) is checked. All work items, acceptance criteria and test items are checked: CI 45311745699 passed ThreadComposerHostedTests (3 tests), and the gallery image thread-external-composer-light.png is from the run of 2026-11-24 05:37.
    - next: none. The task is in done.
  timestamp: 2026-11-24T12:44:31.658176+00:00
position_column: done
position_ordinal: ffffffffa080
title: A read-only thread can show a composer whose submit goes to a host closure (TestudoApp D212 5.3/5.4)
---
## What
TestudoApp D212 (design `/Users/wballard/github/swissarmyhammer/TestudoApp/features/session-import-redesign.md`, sections 5.3 and 5.4): a read-only tab of an external session (a Claude Code session that Testudo shows from its file) must let the user type a prompt. The first prompt continues the session: the host copies the session into a new Testudo session and sends the prompt there. Testudo has `takeExternalPrompt` ready.

Today `Sources/AgentViewKit/Thread/AgentThreadView.swift` shows no composer slot for a read-only session (see the doc near "TestudoApp D208 (i)", lines near 62 and 656).

Work:
- [x] Add a public option for a read-only thread to show the composer, with a submit that goes to a host closure, not to an ACP session. For example `.threadComposer(placeholder: String, onSubmit: @escaping (String) async -> Void)`. Read how the default composer (`DefaultThreadComposer`, `PromptInput`) submits today, and reuse it. Do not make a second composer.
- [x] The placeholder text comes from the host, for example "Message to continue in Testudo".
- [x] A submit calls the host closure one time with the text, and then the composer clears. An empty text does not submit.
- [x] A read-only thread with no such option still shows no composer (no change for D208 shared sessions).
- [x] A gallery screen of a read-only thread with this composer.

## Acceptance Criteria
- [x] With the option, a read-only thread shows the composer with the host placeholder.
- [x] A submit calls the host closure exactly one time with the text, and the composer clears.
- [x] Without the option, a read-only thread shows no composer.

## Tests
- [x] Headless unit tests first (they fail before the change): the option sets the environment or slot; a submit calls the host one time with the text; the text clears; an empty text does not call the host.
- [x] `swift test` in the root: all pass, no code warnings.
- [x] A hosted test (type, press Return, the host closure gets the text) and the gallery screen: write and build them; run them when the screen is free (`cd IntegrationTests && swift test --filter <Name>`; `HOME=<temp> swift test --package-path ScreenshotTests`).

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass. #d212

## Review Findings (2026-11-23 17:21)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 9 file(s) reviewed, 5 not reviewed.

> 4 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 4 file(s)

> 1 file(s) not reviewed — no validator matched:
> - `ARCHITECTURE.md` — no validator matches this file

- [x] `IntegrationTests/Tests/IntegrationTests/Thread/ThreadComposerHostedTests.swift:99` `reuse/reuse` — The new static func draftText(of:) repeats the body of ComposerDraftHostedTests.draftText. Both files are in the same IntegrationTests target. Two copies can drift apart, and a fix to one will not reach the other. Move draftText(of:) to one shared helper in the target, such as ComposerHarness beside mountThread and typePrompt, and call it from both test suites. Delete the copy in ThreadComposerHostedTests.
