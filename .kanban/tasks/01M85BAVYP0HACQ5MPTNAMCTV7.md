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
- actor: claude-code
  id: 01m85ddn8chdxy9nh2n0c52803
  text: |-
    ### review — findings
    - evidence: `review sha HEAD~1..HEAD` (commit 9420cf96): 1 finding (1 confirmed, 1 refuted) — Tests/AgentViewKitTests/Thread/ThreadComposerCommandTests.swift:41 `reuse/reuse`.
    - next: Move the hold support (isHeld, hold, release) into the existing ThreadComposerTests.HostRecord, or make one shared test helper that both suites use. Delete the duplicate HostRecord class from ThreadComposerCommandTests.swift. Then run /review again.
  timestamp: 2026-11-23T23:56:21.132787+00:00
- actor: claude-code
  id: 01m85decm355tf6wyw9avr39s0
  text: |-
    ### finish iteration 1 — findings
    - implement: changed — 7 files
    - test: green — swift test 1714 + 59
    - commit: 9420cf96
    - review: findings — Tests/AgentViewKitTests/Thread/ThreadComposerCommandTests.swift:41
  timestamp: 2026-11-23T23:56:45.059384+00:00
- actor: claude-code
  id: 01m85dx7n7yn650wk2jpj3kb7f
  text: |-
    Iteration 2 (implement):
    - Finding `reuse/reuse` (ThreadComposerCommandTests.swift:41): the hold support (`isHeld`, `hold`, `release`) and `@Observable` moved into `ThreadComposerTests.HostRecord`. The duplicate class is deleted. ThreadComposerCommandTests uses `ThreadComposerTests.HostRecord`.
    - Decision 2 (TestudoApp; Testudo D108 and D100) recorded on the card as a Work item and two Acceptance Criteria, then done with TDD. RED: 4 new tests failed (the payload Send was not available); the no-host test passed (it keeps the old rule). GREEN after the change.
    - `AgentCommandTarget.hasHostComposer` is now computed from the new `hostComposer: ThreadComposerRoute?`, because the payload path needs the closure. `AgentCommandMount.Scope.hostComposer` carries it.
    - One guard for both paths: `AgentCommandTarget.hostSubmission` (a `Task`) is not `nil` while a closure of the host runs. `submitToHost(_:through:)` returns `.cancel` while it runs. `ThreadComposerRouting` sends the submit hook of the slot through the target, so the Return-key fallback of `PromptInputView.submitCommand` (a direct submit when `perform(.send)` is `false`) also cannot call the host a second time. `canSend` is `false` while it runs, with or without a payload.
    - The reason "This session is read-only. Type the message in the composer." stays in use for a read-only session with no composer of the host, so the catalog keeps it.
    - Docs: `AgentCommandTarget`, `threadComposer(placeholder:onSubmit:)`, `ThreadComposerRouting`, and the read-only section of ARCHITECTURE.md.

    ### implement — changed
    - evidence: `swift test` (root): 1718 tests in 193 suites and 59 tests in 12 suites passed, no code warnings; `swift build --build-tests` in IntegrationTests and ScreenshotTests: exit 0. Files: Sources/AgentViewKit/Commands/AgentCommandTarget.swift, Sources/AgentViewKit/Commands/AgentCommandScope.swift, Sources/AgentViewKit/Thread/ThreadComposer.swift, ARCHITECTURE.md, Tests/AgentViewKitTests/Thread/ThreadComposerCommandTests.swift, Tests/AgentViewKitTests/Thread/ThreadComposerTests.swift.
    - next: /review. Hosted tests to run on CI or when the screen is free: IntegrationTests `ThreadComposerHostedTests` (the submit hook of the slot now goes through the target).
  timestamp: 2026-11-24T00:04:51.495886+00:00
- actor: claude-code
  id: 01m85e2nxbygydq0wby0267mt7
  text: |-
    ### review — findings
    - evidence: review sha HEAD~1..HEAD (f2b89b2a): 1 finding (1 confirmed, 2 refuted). Tests/AgentViewKitTests/Thread/ThreadComposerCommandTests.swift:177 `test-integrity/no-test-cheating`. The prior finding (2026-11-23 17:54) is checked. Implement evidence: swift test 1718 + 59 pass; builds clean.
    - next: Implement the open item in "Review Findings (2026-11-23 18:05)". Make the test wait until the run ends before the check of `host.texts`, or hold the host and prove that a second submit does not call it. Apply the same correction to each test in the file that checks a count before the run ends. The task stays in review.
  timestamp: 2026-11-24T00:07:49.931062+00:00
- actor: claude-code
  id: 01m85e3cfkz0ax891ww7d7vqp1
  text: |-
    ### finish iteration 2 — findings
    - implement: changed — 6 files
    - test: green — swift test 1718 + 59
    - commit: f2b89b2a
    - review: findings — Tests/AgentViewKitTests/Thread/ThreadComposerCommandTests.swift:177
  timestamp: 2026-11-24T00:08:13.043512+00:00
- actor: claude-code
  id: 01m85eg4qbw6rjnd623w4ffa9q
  text: |-
    Finding ThreadComposerCommandTests.swift:177 (test-integrity/no-test-cheating) is fixed.
    - New helper `registryFixture(heldSendTo:)`: it registers the scope with a held host, runs a Send with a text payload, and waits (ObservationWait, bounded) until the host has the payload. Three tests use it: aSendWithATextPayloadGivesThePayloadToTheHostOneTime, aSendWithATextPayloadIsNotAvailableWhileTheHostRuns, aComposerSubmitWhileTheHostRunsDoesNotCallTheHost.
    - aSendWithATextPayloadGivesThePayloadToTheHostOneTime: the host is held. A second Send runs through `target.run`, which returns before the check. A Send that does not run starts no run of the host. The test then asserts `!isSecondSendRun && host.texts == [prompt]`.
    - aComposerSubmitWhileTheHostRunsDoesNotCallTheHost: the earlier test checked the count while the run was held, but with the guard removed its `await submitToHost` waited with no bound for the held closure. Now the submit runs in its own task and writes an observable `SubmitRecord`. The bounded wait ends when the submit returns or when the host gets a second prompt. The test then asserts `.cancel` and `host.texts == [prompt]`.
    - ThreadComposerTests.HostRecord keeps each held closure, and `release()` lets each one return. Before, a second hold replaced the first, and the first never returned.
    - The thread tests that check a count wait until the draft is empty, which is the end of the run, so they did not change.
    - Guard removal check: with `guard hostSubmission == nil else { return false }` in `canSend` removed, tests 1 and 2 fail. With `guard hostSubmission == nil else { return .cancel }` in `submitToHost` removed, test 3 fails at once with no hang. The guards are restored, and `git diff Sources` is empty.
  timestamp: 2026-11-24T00:15:11.083162+00:00
- actor: claude-code
  id: 01m85eg6em46gay71jecqy64yq
  text: |-
    ### implement — changed
    - evidence: 2 files — Tests/AgentViewKitTests/Thread/ThreadComposerCommandTests.swift, Tests/AgentViewKitTests/Thread/ThreadComposerTests.swift; swift test 1718 + 59 passed, no code warnings
    - next: review
  timestamp: 2026-11-24T00:15:12.852669+00:00
position_column: doing
position_ordinal: '8180'
title: A read-only thread with the composer of the host registers Send Message and Focus Composer
---
## What
Found during ^dzszz2p (`.threadComposer(placeholder:onSubmit:)`, TestudoApp D212). A read-only thread with the composer of the host shows the composer, but its scope registers no verb of the `compose` group (`AgentCommandTarget.registers(_:)` drops each `changesSession` verb when `session.isReadOnly`). Return in the editor submits, because `PromptInputView.submitCommand` falls back to a direct submit when `perform(.send)` returns `false`. But Send Message, Focus Composer and Mention… are not in the menus, the palette or the keys.

Work:
- [x] Decide with the user whether the `compose` verbs register for a read-only thread with the composer of the host (`\.threadComposerRoute` is not `nil`). Stop, Approve, Reject and Fork stay absent.
- [x] If yes: give the state to `AgentCommandTarget` through the mount of the scope (as `isSessionUnavailable`), and register the `compose` verbs.
- [x] Send Message with a text payload goes to the closure of the host when the host gives `.threadComposer`, as a typed message (decision 2 below). Keep the reason "This session is read-only. Type the message in the composer." only for a read-only session with no composer of the host. If the string is then not used, remove it from the catalog.

## Decision
Yes (TestudoApp, for the user, 2026-11-23). Testudo rule D108: each UI action is a command that the palette, the menus and the keys can run. When the host gives `.threadComposer(placeholder:onSubmit:)`, the thread scope of a read-only session registers Send Message, Focus Composer and Mention…, as for a live thread. Send Message goes to the closure of the host one time. While the closure runs, Send Message takes no second submit (the same guard as the Return key). A read-only thread with no composer of the host registers none of them. Stop, Approve, Reject and Fork stay absent.

Decision 2 (TestudoApp, for the user, 2026-11-23; Testudo D108 and D100): a command and a typed action do the same thing, so the palette and the agent can continue the session. When the host gives `.threadComposer`, Send Message with a text payload also goes to the closure of the host, the same as a typed message. With the same guard: no submit while the closure runs, and a blank payload is not available. The reason "This session is read-only. Type the message in the composer." stays only when the host gives no composer.

## Acceptance Criteria
- [x] A read-only thread with the composer of the host registers Send Message, Focus Composer and Mention… at the thread path.
- [x] A read-only thread with no composer of the host registers none of them.
- [x] Stop, Approve Request, Reject Request and Fork from Here stay absent from a read-only thread with the composer of the host.
- [x] Send Message runs the closure of the host one time with the draft text, and clears the draft.
- [x] Send Message is disabled while the closure of the host runs, and when the text is blank.
- [x] A Send with a text payload sends nothing to the read-only model.
- [x] With the composer of the host, Send Message with a text payload calls the closure of the host one time with the payload. With no composer of the host, it is not available, with the reason "This session is read-only. Type the message in the composer.".
- [x] With the composer of the host, Send Message with a text payload is not available while the closure of the host runs, and for a blank payload.

## Tests
- [x] Headless: with the composer of the host, the registry of a read-only thread has Send Message, Focus Composer and Mention…; without it, it does not.
- [x] Headless: the change verbs of the groups `control` and `fork` stay absent with the composer of the host.
- [x] Headless: Send Message runs the host closure one time with the draft text and clears the draft.
- [x] Headless: Send Message is disabled while the closure runs, and when the text is blank.
- [x] Headless: with the composer of the host, a Send with a text payload calls the host closure one time with the payload; with no composer of the host, it is not available with the read-only reason.
- [x] Headless: with the composer of the host, a Send with a text payload is not available while the closure runs and for a blank payload, and a composer submit while the closure runs does not call the host.
- [x] `swift test` in the root: all pass, no code warnings.
- [x] `swift build --build-tests` in IntegrationTests and ScreenshotTests: no errors.

## Workflow
- Use /tdd: write the headless tests first, see them fail, then write the change.
- Do not run a hosted suite (the user needs the screen). List each hosted test to run on CI or when the screen is free.

## Review Findings (2026-11-23 17:54)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 5 file(s) reviewed, 4 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

> 2 file(s) not reviewed — no validator matched:
> - `ARCHITECTURE.md` — no validator matches this file
> - `Sources/AgentViewKit/Resources/Localizable.xcstrings` — no validator matches this file

- [x] `Tests/AgentViewKitTests/Thread/ThreadComposerCommandTests.swift:41` `reuse/reuse` — The new HostRecord class reimplements the existing HostRecord of ThreadComposerTests in the same test module. Both keep the texts that the host closure gets, and both have a take(_:) method. The new class adds only the hold and release behavior. The author should have extended the existing HostRecord with an isHeld option, so that one helper stays canonical. Move the hold support (isHeld, hold, release) into the existing ThreadComposerTests.HostRecord, or make one shared test helper that both suites use. Delete the duplicate class from ThreadComposerCommandTests.swift.

## Review Findings (2026-11-23 18:05)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 5 file(s) reviewed, 3 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

> 1 file(s) not reviewed — no validator matched:
> - `ARCHITECTURE.md` — no validator matches this file

- [x] `Tests/AgentViewKitTests/Thread/ThreadComposerCommandTests.swift:177` `test-integrity/no-test-cheating` — The test is named for one submission, but it checks `host.texts` as soon as the first text appears. It does not wait for the run to end. A second call to the host that lands after this check would not fail the test. So the test cannot reliably prove that the host gets the payload only one time, which is what its name and doc comment say it proves. This is a weakened assertion: it does not check the property it claims. Wait for the run to finish before the check. For example, wait until the draft is empty, or until the `hostSubmission` run has ended, and only then assert `host.texts == [Self.prompt]`. Or hold the host (`isHeld: true`), wait for the first text, call `submitToHost` or a second Send, and assert that `host.texts.count` stays at 1.
