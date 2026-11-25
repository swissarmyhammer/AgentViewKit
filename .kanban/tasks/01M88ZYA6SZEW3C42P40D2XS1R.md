---
assignees:
- claude-code
depends_on:
- 01M88ZXW64E4BT7ZQMKB0A65BH
position_column: todo
position_ordinal: '8180'
title: Adopt the one EditorKit focus ring and focus background
---
Request from TestudoApp (relayed by testudoapp-9a, 2026-11-25): one focus ring style and one focus background style in all kits. EditorKit defines both and sends the API. Blocked until that API is on EditorKit main.

## What

- [ ] `Sources/AgentViewKitStyle/Theme/SelectableSurface.swift`: draw the focus look only with the EditorKit focus ring API and focus background API. Keep the selection fill as EditorKit defines it.
- [ ] Each place in `Docs/decisions/focus-audit.md` (from ^b0a65bh) gets its target look (ring, background, or both) through `SelectableSurface` or through the EditorKit API directly. No second style.
- [ ] Update `Docs/decisions/focus-audit.md` and `plan.md` with the EditorKit API names, in ASD-STE100 Simplified Technical English.

## Acceptance Criteria

- [ ] Every focus visual in the audit uses the EditorKit focus ring or focus background, and no other focus look.
- [ ] `FocusLookTests` (from ^b0a65bh) checks the EditorKit focus ring and focus background on each focusable view. No source-scan test (user rule of 2026-10-30).

## Tests

- [ ] A unit test that mounts a focused card (for example `PermissionView`) and a focused chip, and reads that both use the EditorKit focus API (an environment or an accessibility value that EditorKit exposes, or the modifier type).
- [ ] `HOME=$(mktemp -d) swift test` passes with 0 failures and 0 warnings. Gallery images for review (light and dark) after the change.

## EditorKit plan (2026-11-25, names can change in review; wait for the final names and shas)

- `EditorFocusIndicatorKind`: `.ring`, `.background`, `.ringAndBackground`.
- `.editorFocusIndicator(_:isFocused:radius:)` and `.editorFocusIndicator(_:isFocused:cornerRadius:)`.
- Tokens: `EditorStyle.focusRingWidth` (1 pt) and `EditorStyle.focusRingOpacity`. The ring is a 1 pt band inside the control bounds, so the frame does not change.
- `editorFocusRing` and `scopeFocusRing` stay only as wrappers. The 3 pt band is deleted.
- The focus background stays `SelectionFill` (`selectableItem`), which `SelectableSurface` uses now.
- EditorKit turns off the system ring in its AppKit views, its buttons and the inspector.

## Workflow
- Use `/tdd` — write failing tests first, then implement to make them pass.
- When done: push, and send the sha to testudoapp-9a.