---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: 'Focus audit: list every focus visual and turn off every system focus effect'
---
Request from TestudoApp (relayed by testudoapp-9a, 2026-11-25). User rule for all kits: "we need a 'focus ring' -- one style -- and a 'focus background' like we do for the cards and chips -- again ONE STYLE. I'm ok if we decide to use 'ring and background' together, but I'm not OK with multiple different 'ring' and 'background' focus styles."

EditorKit defines the ONE focus ring and the ONE focus background. This card is the AVK part that does not need the EditorKit API. The adoption is a second card that depends on this card.

## What

- [ ] Audit: find every focus visual in `Sources/AgentViewKit` and `Sources/AgentViewKitStyle`: rows, messages, composer, pills, banners, buttons, cards, chips, list rows. Search for `focusable(`, `focusEffectDisabled`, `@FocusState`, `.focused(`, `isFocused`, `selectableSurface`, `selectionSurface`, `AgentItemScope` `.fill`, and each stroke or fill that depends on a focus value. Known places: `Sources/AgentViewKitStyle/Theme/SelectableSurface.swift`, `Sources/AgentViewKit/Commands/AgentItemScope.swift:114`, `Sources/AgentViewKit/Lists/AgentRowList.swift:658,672,768,773`, `Sources/AgentViewKit/HumanInTheLoop/PermissionView.swift:197,505`, `Sources/AgentViewKit/HumanInTheLoop/RequestDeck.swift:675`, `Sources/AgentViewKit/Elicitation/ElicitationView.swift:195`, `Sources/AgentViewKit/Elicitation/ElicitationURLConsentView.swift:211`, `Sources/AgentViewKit/Attachments/AttachmentView.swift:239`. Write the result as a table in `Docs/decisions/focus-audit.md`: place, what it draws now (system ring, own ring, fill), and the target (the EditorKit ring, the EditorKit background, or both).
- [ ] Turn off every system focus effect: each focusable view of the kit that does not have `.focusEffectDisabled()` gets it. This includes buttons and fields that show the system focus ring.
- [ ] Remove each focus ring or focus fill that AVK draws itself and that is not the shared `SelectableSurface` (EditorKit `.selectableItem`). Each focus look then goes through `SelectableSurface`, so the adoption card changes one place.
- [ ] `plan.md`: one paragraph on the one-focus-style rule, in ASD-STE100 Simplified Technical English.

## Acceptance Criteria

- [ ] `Docs/decisions/focus-audit.md` lists every focus visual with its target.
- [ ] No source line under `Sources/` has a `.focusable(` without a `.focusEffectDisabled()` on the same view.
- [ ] No AVK file draws a focus ring or a focus fill outside `SelectableSurface.swift`.

## Tests

- [ ] No source-scan test (user rule of 2026-10-30: "no tests that scan source text or check docs"). Behavior tests: new `Tests/AgentViewKitTests/Style/FocusLookTests.swift` mounts each focusable view of the audit (for example `PermissionView`, an `AgentRowList` row, an attachment chip) in a window that is never ordered in, gives it the focus, and checks that it shows the `SelectableSurface` focus fill and no system focus ring (`focusEffectDisabled` in the environment, or the accessibility or modifier value that the kit exposes). The review step checks the code for other focus looks.
- [ ] `HOME=$(mktemp -d) swift test --filter FocusLookTests` passes, then the full `HOME=$(mktemp -d) swift test` passes with 0 failures and 0 warnings.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.
- Start after the AVK scroll profile run ends (one screen user at a time).