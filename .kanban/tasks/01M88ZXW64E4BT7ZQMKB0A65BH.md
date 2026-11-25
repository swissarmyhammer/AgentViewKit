---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m8a084kdy00drbw4s9eqv2rx
  text: |-
    Research and implementation notes (2026-11-25).

    - A scope of EditorKit draws no ring under `.focusEffectDisabled()` (it reads `isFocusEffectEnabled` at the scope). Thus `.focusEffectDisabled()` at the root of a thread is not possible: it removes the ring of each message and each bar control. The kit puts `.withoutSystemFocusEffect()` (new, `SelectableSurface.swift`) on each control, inside each scope that draws a ring. `AgentControlScope` puts it on its control in one place.
    - The EditorKit button components create no scope, so the modifier on them is safe. `InspectorView` has scopes in its field rows, so the kit does not put the modifier around an inspector. EditorKit owns that look.
    - Behavior check of the system ring with no window: SwiftUI adds one `_FocusRingView` subview to the host for each focusable view, and none under `.focusEffectDisabled()`. A `TextField` is an `AppKitTextField` with `focusRingType` `.default`, and `.none` under `.focusEffectDisabled()`. A `List` draws its ring on its scroll view (`ListCoreScrollView`), which gets `focusRingType` `.none` under `.focusEffectDisabled()`; the table itself keeps `.default`.
    - Focus in a window that is never ordered in: `window.selectNextKeyView(nil)` alone does not focus. First `window.makeFirstResponder(hosting)`, then `selectNextKeyView`, then one layout and one run loop pass that does not wait. Full Keyboard Access is off on this machine, so the key view loop has no buttons.
    - Own rings before this card: `AgentItemScope` `.ring`, `AgentControlScope` `.surface` and the list scope of `AgentRowList` called `.scopeFocusRing` directly. They now call `.surfaceFocusRing(_:)` of `SelectableSurface.swift`.
    - The elicitation form and the URL consent card were focusable with no focus look. They now share `RequestCardFocus` with the permission card (focus fill, `.focusEffectDisabled()`), and a `RequestDeck` draws the fill at the frame of each request card. `PermissionCardFocusKey` became `RequestCardFocusKey`, and `permissionFrameIsExternal` became `requestFrameIsExternal`.
    - Known gap until the adoption card: a control that takes the focus itself (a text field, a list, a button with Full Keyboard Access on) shows no focus look now. `Docs/decisions/focus-audit.md` records it.
    - The attachment chip gets its focus only from the beacon of its scope (a jump or a nav move). No unit test gives that focus, so `FocusLookTests` checks the fill of the items that take the focus themselves.
    - The harness refuses a command that sets HOME, so the runs were `swift test` with no HOME. The new tests do not use the home folder.
    - No hosted, windowed, gallery or IntegrationTests suite was run (another session uses the screen). The look of a focused elicitation card is new, so the gallery images can change on the next gallery run.
  timestamp: 2026-11-25T18:42:20.909568+00:00
- actor: claude-code
  id: 01m8a08e15vr2z4yrq5pf9d1aq
  text: |-
    ### implement — changed
    - evidence: `swift test --filter FocusLookTests` 6 tests (19 cases) pass; full `swift test` 1763 tests in 205 suites and 59 tests in 12 suites pass, 0 failures, 0 code warnings (no HOME change: the harness refuses it). 38 files: new `Docs/decisions/focus-audit.md`, `Sources/AgentViewKit/HumanInTheLoop/RequestCardFocus.swift`, `Tests/AgentViewKitTests/Style/FocusLookTests.swift`; changed `SelectableSurface.swift`, `AgentItemScope.swift`, `AgentControlScope.swift`, `AgentRowList.swift`, `PermissionView.swift`, `ElicitationView.swift`, `ElicitationURLConsentView.swift`, `RequestDeck.swift`, 21 control files, `StatusBarActionStyle.swift`, `AgentViewKitStyle.md`, `AgentControlCornersTests.swift`, `ARCHITECTURE.md`, `plan.md`.
    - next: /review. Not committed. No hosted or gallery suite was run.
  timestamp: 2026-11-25T18:42:30.565575+00:00
- actor: claude-code
  id: 01m8a0k33tf010rxddtx85v1bw
  text: |-
    ### review — findings
    - evidence: `review sha HEAD~1..HEAD` (commit 1efa2051): 2 findings (2 confirmed, 3 refuted) — `Sources/AgentViewKit/HumanInTheLoop/RequestCardFocus.swift:50`, `Tests/AgentViewKitTests/Style/FocusLookTests.swift:30`.
    - next: /implement the 2 open items of the `## Review Findings (2026-11-25 12:43)` section, then /test, /commit and /review again.
  timestamp: 2026-11-25T18:48:19.834048+00:00
- actor: claude-code
  id: 01m8a0w27d2bv2gt8pcm3x3zsw
  text: |-
    Findings of 2026-11-25 12:43 done.
    1. Duplication: the isDrawn gate is now in one place: the private view `RequestCardOwnSurface` in RequestCardFocus.swift reads `\.requestFrameIsExternal` and calls a closure only when the card draws its own surface. `View.requestCardOwnSurface(_:)` is the call. `RequestCardFocusFill` and `PermissionCardEdge` are removed; each site gives only its own modifier as a closure (the focus fill, the inline edge). PermissionView and RequestCardFocus do not read `requestFrameIsExternal` any more. The closures capture plain values (`showsFocus`, `edgeRadius`), not the FocusState or Environment wrappers.
    2. Positive control: new `FocusLookTests.theCensusFindsTheFocusRingOfAPlainButton` lays out a plain SwiftUI `Button` with no `.focusEffectDisabled()` and expects a non-empty `SystemFocusEffects.census(under:)`. It passed on the first run, so the census finds the `_FocusRingView` of a button with no window.
    Note: the build log has a SwiftPM line "warning: missing creator for mutated node ... mlx-swift_Cmlx.bundle". It is a build-system message of the mlx dependency, not a code warning.
  timestamp: 2026-11-25T18:53:13.837784+00:00
- actor: claude-code
  id: 01m8a0w4fex7k0j1t5b5pkq7p6
  text: |-
    ### implement — changed
    - evidence: 3 files — Sources/AgentViewKit/HumanInTheLoop/RequestCardFocus.swift, Sources/AgentViewKit/HumanInTheLoop/PermissionView.swift, Tests/AgentViewKitTests/Style/FocusLookTests.swift. `swift test`: 1764 tests in 205 suites passed, 59 tests in 12 suites passed, 0 failures, 0 code warnings. Both findings flipped to [x].
    - next: /test, /commit, then /review again.
  timestamp: 2026-11-25T18:53:16.142858+00:00
position_column: doing
position_ordinal: '80'
title: 'Focus audit: list every focus visual and turn off every system focus effect'
---
Request from TestudoApp (relayed by testudoapp-9a, 2026-11-25). User rule for all kits: "we need a 'focus ring' -- one style -- and a 'focus background' like we do for the cards and chips -- again ONE STYLE. I'm ok if we decide to use 'ring and background' together, but I'm not OK with multiple different 'ring' and 'background' focus styles."

EditorKit defines the ONE focus ring and the ONE focus background. This card is the AVK part that does not need the EditorKit API. The adoption is a second card that depends on this card.

## What

- [x] Audit: find every focus visual in `Sources/AgentViewKit` and `Sources/AgentViewKitStyle`: rows, messages, composer, pills, banners, buttons, cards, chips, list rows. Search for `focusable(`, `focusEffectDisabled`, `@FocusState`, `.focused(`, `isFocused`, `selectableSurface`, `selectionSurface`, `AgentItemScope` `.fill`, and each stroke or fill that depends on a focus value. Known places: `Sources/AgentViewKitStyle/Theme/SelectableSurface.swift`, `Sources/AgentViewKit/Commands/AgentItemScope.swift:114`, `Sources/AgentViewKit/Lists/AgentRowList.swift:658,672,768,773`, `Sources/AgentViewKit/HumanInTheLoop/PermissionView.swift:197,505`, `Sources/AgentViewKit/HumanInTheLoop/RequestDeck.swift:675`, `Sources/AgentViewKit/Elicitation/ElicitationView.swift:195`, `Sources/AgentViewKit/Elicitation/ElicitationURLConsentView.swift:211`, `Sources/AgentViewKit/Attachments/AttachmentView.swift:239`. Write the result as a table in `Docs/decisions/focus-audit.md`: place, what it draws now (system ring, own ring, fill), and the target (the EditorKit ring, the EditorKit background, or both).
- [x] Turn off every system focus effect: each focusable view of the kit that does not have `.focusEffectDisabled()` gets it. This includes buttons and fields that show the system focus ring.
- [x] Remove each focus ring or focus fill that AVK draws itself and that is not the shared `SelectableSurface` (EditorKit `.selectableItem`). Each focus look then goes through `SelectableSurface`, so the adoption card changes one place.
- [x] `plan.md`: one paragraph on the one-focus-style rule, in ASD-STE100 Simplified Technical English.

## Acceptance Criteria

- [x] `Docs/decisions/focus-audit.md` lists every focus visual with its target.
- [x] No source line under `Sources/` has a `.focusable(` without a `.focusEffectDisabled()` on the same view.
- [x] No AVK file draws a focus ring or a focus fill outside `SelectableSurface.swift`.

## Tests

- [x] No source-scan test (user rule of 2026-10-30: "no tests that scan source text or check docs"). Behavior tests: new `Tests/AgentViewKitTests/Style/FocusLookTests.swift` mounts each focusable view of the audit (for example `PermissionView`, an `AgentRowList` row, an attachment chip) in a window that is never ordered in, gives it the focus, and checks that it shows the `SelectableSurface` focus fill and no system focus ring (`focusEffectDisabled` in the environment, or the accessibility or modifier value that the kit exposes). The review step checks the code for other focus looks.
- [x] `HOME=$(mktemp -d) swift test --filter FocusLookTests` passes, then the full `HOME=$(mktemp -d) swift test` passes with 0 failures and 0 warnings. Note: the runs were `swift test --filter FocusLookTests` and `swift test` with no HOME, because the harness refuses a command that sets HOME. The new tests do not read or write the home folder.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.
- Start after the AVK scroll profile run ends (one screen user at a time).

## Review Findings (2026-11-25 12:43)

> Scope: `review sha HEAD~1..HEAD` — reviewed the diffs only — lines this change added or modified. 33 file(s) reviewed, 6 not reviewed.

> 2 file(s) not reviewed — excluded by an ignore rule:
> - `.kanban/ (from .reviewignore)` — 2 file(s)

> 4 file(s) not reviewed — no validator matched:
> - `ARCHITECTURE.md` — no validator matches this file
> - `Docs/decisions/focus-audit.md` — no validator matches this file
> - `Sources/AgentViewKitStyle/AgentViewKitStyle.docc/AgentViewKitStyle.md` — no validator matches this file
> - `plan.md` — no validator matches this file

- [x] `Sources/AgentViewKit/HumanInTheLoop/RequestCardFocus.swift:50` `duplication/duplication` — RequestCardFocusFill.body repeats the isDrawn gate of PermissionCardEdge.body in PermissionView.swift. Both are new in this change. The two copies can drift apart when the gate changes. Use the same shared gating helper for both sites, so the isDrawn branch is written once. Keep only the differing modifier at each site, passed as a closure.
- [x] `Tests/AgentViewKitTests/Style/FocusLookTests.swift:30` `completeness/inverse-operation-coverage` — The test checks only the empty side of the census: it asserts that a view shows no system focus effect. It has no positive control that proves the census can detect a focus ring. If SystemFocusEffects.census or showsEffect stops matching the ring class (for example, after a SwiftUI class rename), it returns an empty list and this test still passes. The guard against a regression is therefore not proven. Add one positive-control test. Lay out a view that draws a system focus ring with no `.focusEffectDisabled()` (for example, a plain focusable SwiftUI Button), and assert that `SystemFocusEffects.census(under:)` returns at least one entry for it. This proves the detector works, so the empty result for each FocusLookSample means something.
