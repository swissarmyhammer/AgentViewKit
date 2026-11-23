---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m85crb7cjpt71s3960e4pmyj
  text: |-
    Research (implement):
    - `AgentCommandTarget.registers(_:)` drops each verb of a `changesSession` group when `session.isReadOnly`. The registration (`AgentCommandRegistration.register(_:at:into:groupsOff:)`) reads `registers` only in the mount that owns the scope (`AgentCommandMount.Scope`). A mount with `scope: nil` (a thread in a scope of the host) does not register again. Thus the state that changes the registry must come with the `Scope` of the mount, as `forkFromHere` does: `AgentCommandScope` reads `\.threadComposerRoute` from the environment and gives it to the target through the mount.
    - Send Message with no payload calls `composer.submit()` of the hook of `PromptInputView`. That submit goes through `\.composerSubmitHook`, which `ThreadComposerRouting` sets to the route of the host in a read-only thread. `composer.canSubmit()` is `false` while `isSubmitting` is `true` and for a blank text. Thus the guard of the Return key is also the guard of Send Message, with no new state.
    - A Send with a text payload calls `SessionModel.startPrompt(text:)`. A read-only model refuses it (`SessionModelError.readOnly`). In a read-only scope, the payload path must not reach the model.
    - The draft of the default composer is in `PromptDraftStore.shared` (an `@Observable` `PromptDraft`), so a headless test can set and read it with no window.
  timestamp: 2026-11-23T23:44:42.732253+00:00
- actor: claude-code
  id: 01m85d84b0k95vafk6mbsxm0kb
  text: |-
    Implementation landed (TDD: 9 new headless tests failed first with 11 issues, then passed).
    - `AgentCommandTarget.hasHostComposer`: `registers(_:)` keeps the verbs of `compose` for a read-only session when it is `true`. `control` and `fork` stay absent.
    - `AgentCommandScope` reads `\.threadComposerRoute` from the environment (as `forkFromHere`) and gives it through `AgentCommandMount.Scope.hasHostComposer`, before the mount registers. The route is read in the scope and not given by the thread view as `isUnavailable`, because only the owned mount registers: a value that a `scope: nil` mount writes does not change the registry.
    - Send Message with no payload submits the composer, so `PromptInputView.canSubmit` is the guard (blank text, submit in progress). No new state.
    - A Send with a text payload in a read-only session is not available, with the new reason "This session is read-only. Type the message in the composer." (catalog entry added), because the model refuses a prompt (`SessionModelError.readOnly`).
    - Docs: `AgentCommandTarget`, `AgentCommandScope`, `AgentCommandGroup.changesSession`, `threadComposer(placeholder:onSubmit:)`, and the read-only section of ARCHITECTURE.md.

    ### implement — changed
    - evidence: `swift test` (root): 1714 tests in 193 suites and 59 tests in 12 suites passed, no build warnings; `swift build --build-tests` in IntegrationTests and ScreenshotTests: exit 0. Files: Sources/AgentViewKit/Commands/AgentCommandTarget.swift, Sources/AgentViewKit/Commands/AgentCommandScope.swift, Sources/AgentViewKit/Commands/AgentCommandGroup.swift, Sources/AgentViewKit/Thread/ThreadComposer.swift, Sources/AgentViewKit/Resources/Localizable.xcstrings, ARCHITECTURE.md, Tests/AgentViewKitTests/Thread/ThreadComposerCommandTests.swift (new).
    - next: /review. Hosted tests to run on CI or when the screen is free: IntegrationTests `ThreadComposerHostedTests` (Return now goes through the registered Send Message in a read-only thread), ScreenshotTests suites that use `SharedThreadFixtures.swift`.
  timestamp: 2026-11-23T23:53:19.968060+00:00
position_column: doing
position_ordinal: '8180'
title: A read-only thread with the composer of the host registers Send Message and Focus Composer
---
## What
Found during ^dzszz2p (`.threadComposer(placeholder:onSubmit:)`, TestudoApp D212). A read-only thread with the composer of the host shows the composer, but its scope registers no verb of the `compose` group (`AgentCommandTarget.registers(_:)` drops each `changesSession` verb when `session.isReadOnly`). Return in the editor submits, because `PromptInputView.submitCommand` falls back to a direct submit when `perform(.send)` returns `false`. But Send Message, Focus Composer and Mention… are not in the menus, the palette or the keys.

Work:
- [x] Decide with the user whether the `compose` verbs register for a read-only thread with the composer of the host (`\.threadComposerRoute` is not `nil`). Stop, Approve, Reject and Fork stay absent.
- [x] If yes: give the state to `AgentCommandTarget` through the mount of the scope (as `isSessionUnavailable`), and register the `compose` verbs.

## Decision
Yes (TestudoApp, for the user, 2026-11-23). Testudo rule D108: each UI action is a command that the palette, the menus and the keys can run. When the host gives `.threadComposer(placeholder:onSubmit:)`, the thread scope of a read-only session registers Send Message, Focus Composer and Mention…, as for a live thread. Send Message goes to the closure of the host one time. While the closure runs, Send Message takes no second submit (the same guard as the Return key). A read-only thread with no composer of the host registers none of them. Stop, Approve, Reject and Fork stay absent.

## Acceptance Criteria
- [x] A read-only thread with the composer of the host registers Send Message, Focus Composer and Mention… at the thread path.
- [x] A read-only thread with no composer of the host registers none of them.
- [x] Stop, Approve Request, Reject Request and Fork from Here stay absent from a read-only thread with the composer of the host.
- [x] Send Message runs the closure of the host one time with the draft text, and clears the draft.
- [x] Send Message is disabled while the closure of the host runs, and when the text is blank.
- [x] A Send with a text payload sends nothing to the read-only model.

## Tests
- [x] Headless: with the composer of the host, the registry of a read-only thread has Send Message, Focus Composer and Mention…; without it, it does not.
- [x] Headless: the change verbs of the groups `control` and `fork` stay absent with the composer of the host.
- [x] Headless: Send Message runs the host closure one time with the draft text and clears the draft.
- [x] Headless: Send Message is disabled while the closure runs, and when the text is blank.
- [x] `swift test` in the root: all pass, no code warnings.
- [x] `swift build --build-tests` in IntegrationTests and ScreenshotTests: no errors.

## Workflow
- Use /tdd: write the headless tests first, see them fail, then write the change.
- Do not run a hosted suite (the user needs the screen). List each hosted test to run on CI or when the screen is free.
- Do not commit. Leave the task in doing. #d212