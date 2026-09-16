---
comments:
- actor: claude-code
  id: 01m2p34k2t1mhas4bgjp1r3qcx
  text: 'Requirement from ^8xcmw7e (done): `PermissionModePicker(options:)` is in Sources/AgentViewKit/Config/PermissionModePicker.swift. Put it in the composer accessory and pass `thread.configOptions`. It is empty when the thread has no `mode` select option. `ConfigOptionsView(options:style: .menu)` is the toolbar menu for the other options. Test note: do not press a segment of the segmented picker in a hosted test; the press stops the test process (see the `press` doc of HostedViewHarness).'
  timestamp: 2026-09-16T21:49:32.634951+00:00
- actor: claude-code
  id: 01m2p69b7j6cjczh1t5dw1arhb
  text: |-
    ### finish iteration 1 — findings
    - implement: added PromptInputView, PromptEditorContext, PromptSubmitAction, StockPromptEditor, DefaultPromptAccessory, and 11 hosted tests.
    - test: green. AgentViewKitTests 857, AgentViewKitACPTests 93, AgentViewKitRouterTests 71, PackageFileSupportTests 20, AgentViewKitFoundationModelsTests 1.
    - commit: 1836b8d
    - review: 2 findings (reuse: shared thread harness; reuse: shared editable text view search). Task stays in doing for the fix.
  timestamp: 2026-09-16T22:44:34.162950+00:00
- actor: claude-code
  id: 01m2p6ve50prgcqtg6gdcnb1gw
  text: |-
    ### finish iteration 2 — done
    - implement: fixed both reuse findings. Added `threadViewHarness(size:actions:thread:content:)`, `HostedViewHarness.firstEditableTextView(of:)`, and `focusFirstEditableTextView(of:)` in AgentViewKitTestSupport, with 8 tests. The prompt, AgentAuthView, AuthorizationView, and TerminalView tests use them.
    - test: green. AgentViewKitTests 865, AgentViewKitACPTests 93, AgentViewKitRouterTests 71, PackageFileSupportTests 20, AgentViewKitFoundationModelsTests 1.
    - commit: 085330f
    - review: clean (0 findings, all prior items checked). Task moved through review to done.
  timestamp: 2026-09-16T22:54:26.976851+00:00
depends_on:
- 01M21A9KJGPPJE0X01JE0B9V33
- 01M21ABMYXZQRNRDGB3DR6RK73
- 01M21BCRF2JZ6W49NKXHE8KKT1
- 01M21CAWYA16NQ5MKZKBBH4DS6
position_column: done
position_ordinal: ad80
title: 'PromptInputView: slots, PromptEditorContext, stock editor, submit and stop (plan §7, §9 D)'
---
## What
Create `Sources/AgentViewKit/Input/PromptInputView.swift`, `PromptEditorContext.swift`, `StockPromptEditor.swift`, and `DefaultPromptAccessory.swift`, per plan.md §7 and §9 D. The EditorKit editor, the attachment chips, and the suggestions, mic, and tool toggles come in their own tasks.

- `PromptInputView<Editor, Accessory>` with the constrained-extension overloads from §7. Default `Editor == StockPromptEditor` (a `TextEditor`), `Accessory == DefaultPromptAccessory`.
- `PromptEditorContext`: `text: Binding<AttributedString>`, `placeholder`, `onSubmit`, `commands: [SlashCommand]`.
- `StockPromptEditor(context:)`: Return calls `onSubmit`; Shift-Return inserts a newline.
- `DefaultPromptAccessory`: the submit button in `.glassProminent`. It becomes Stop while `thread.state == .running` and calls `cancel`. Slots for the later chips, suggestions, mic, and tool toggles are empty views here.
- On submit the view calls `AgentThreadActions.send(UserInput(text:attachments:))` and clears the text.
- Accessibility identifiers: `prompt-editor`, `prompt-submit`, `prompt-stop`.

## Acceptance Criteria
- [x] `PromptInputView(text:onSubmit:)` compiles with no closures and mounts `prompt-editor`.
- [x] Return calls `send` with the text and clears the editor; Shift-Return does not, and the text gains a newline.
- [x] While running, `prompt-stop` is present, `prompt-submit` is absent, and a press calls `cancel`.

## Tests
- [x] `Tests/AgentViewKitTests/Input/PromptInputViewHostedTests.swift`: mount, keys, submit and stop through `NoopThreadActions`.
- [x] `swift test --filter AgentViewKitTests` exits 0.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.

## Review Findings (2026-09-16 17:38)

> Scope: `review sha HEAD~1..HEAD` (commit 1836b8d). 5 files reviewed, 0 not reviewed.

- [x] `Tests/AgentViewKitTests/Input/PromptInputViewHostedTests.swift:70` `reuse/reuse` — The `harness` helper function is nearly identical (0.93 similarity) to harness functions in AgentAuthViewHostedTests.swift and AuthorizationViewHostedTests.swift. This common test setup pattern is reimplemented across multiple test suites instead of being extracted to a shared utility. Extract the harness pattern to a shared test utility module (e.g., AgentViewKitTestSupport) with the size parameter optional or parameterized (default to composerSize). Have all test files call this shared harness instead of maintaining separate implementations. (Fixed in 085330f: `threadViewHarness(size:actions:thread:content:)` in AgentViewKitTestSupport, used by the prompt, AgentAuthView, and AuthorizationView tests.)
- [x] `Tests/AgentViewKitTests/Input/PromptInputViewHostedTests.swift:87` `reuse/reuse` — The `firstTextView` function reimplements functionality that already exists as `firstTextField` in TerminalViewHostedTests. Both recursively search for an editable text view in a view hierarchy with identical logic. This duplication should be extracted to a shared test utility. Extract the shared text-view-finding logic to a common test utility module (e.g., AgentViewKitTestSupport) and have both test files import and call it. Alternatively, rename one function and have the other call it or be removed if the name difference is not significant. (Fixed in 085330f: `HostedViewHarness.firstEditableTextView(of:)` and `focusFirstEditableTextView(of:)`; `firstTextView` and `firstTextField` are removed.)

## Review Findings (2026-09-16 17:52)

> Scope: `review sha HEAD~1..HEAD` (commit 085330f). 6 files reviewed, 0 not reviewed. No new findings.
