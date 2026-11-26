---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m8a10f0j23vntgqg3k9y31z5
  text: |-
    ### finish — stuck (blocked by EditorKit)
    - evidence: EditorKit origin/main 80f9a486 has no `EditorFocusIndicatorKind` and no `.editorFocusIndicator(_:isFocused:radius:)` (git grep on Sources). The thin ring tokens (98dfbe5d) are there, but the API of the card is not.
    - next: start this card when EditorKit sends the sha of the focus indicator API.
  timestamp: 2026-11-25T18:55:38.002547+00:00
- actor: claude-code
  id: 01m8b8v931n536m8f72qp2jktd
  text: |-
    ### review — clean
    - evidence: review sha 19fbb15e..0f3778df: 0 findings, 0 confirmed, 1 refuted, 14 attempted, 0 failed. 20 files reviewed. 3 files had no validator (focus-audit.md, AgentViewKitStyle.md, plan.md). Tests: RED: 6 focus tests failed against an empty key. GREEN: 9 of 9 pass. The root swift test on main 0f3778df: 1829 + 59 passed.
    - next: review clean; waits for the gallery images. The gallery item stays open until the gallery runs after the Testudo hold. Do not move the card to done before that item is checked.
  timestamp: 2026-11-26T06:31:51.137240+00:00
- actor: claude-code
  id: 01m8bagny2wq8yyw6rhp05ajwk
  text: |-
    ### done — the gallery item is checked
    - evidence: the review of 19fbb15e..0f3778df was clean (0 findings), and only the gallery item was open. The gallery ran on main a7dd9878 with EK 474081e5: ScreenshotTests 46 tests passed. The images states-permission, states-elicitation-tab, elicitation-form and states-tool-call (light and dark) show the one EK focus fill and no square ring. All IntegrationTests pass on ed44e6e0: 1090 tests, 5 known issues.
  timestamp: 2026-11-26T07:01:00.994070+00:00
depends_on:
- 01M88ZXW64E4BT7ZQMKB0A65BH
position_column: done
position_ordinal: '8180'
title: Adopt the one EditorKit focus ring and focus background
---
Request from TestudoApp (relayed by testudoapp-9a, 2026-11-25): one focus ring style and one focus background style in all kits. EditorKit defines both and sends the API. Blocked until that API is on EditorKit main.

## What

- [x] `Sources/AgentViewKitStyle/Theme/SelectableSurface.swift`: draw the focus look only with the EditorKit focus ring API and focus background API. Keep the selection fill as EditorKit defines it. (b0dc6399: `SelectableSurface` sends the EditorKit focus background kind through `SurfaceFocusIndicatorKey`. Plan A: `.selectableItem` is the one EditorKit focus background, and `.scopeFocusRing` is the EditorKit ring.)
- [x] Each place in `Docs/decisions/focus-audit.md` (from ^b0a65bh) gets its target look (ring, background, or both) through `SelectableSurface` or through the EditorKit API directly. No second style. (2f93899f: `.withoutSystemFocusEffect()` is removed from the EditorKit button components in 17 files.)
- [x] Update `Docs/decisions/focus-audit.md` and `plan.md` with the EditorKit API names, in ASD-STE100 Simplified Technical English. (88f1baca)

## Acceptance Criteria

- [x] Every focus visual in the audit uses the EditorKit focus ring or focus background, and no other focus look. (b0dc6399, 2f93899f, 88f1baca)
- [x] `FocusLookTests` (from ^b0a65bh) checks the EditorKit focus ring and focus background on each focusable view. No source-scan test (user rule of 2026-10-30). (RED: 6 focus tests failed against an empty key. GREEN: 9 of 9 pass.)

## Tests

- [x] A unit test that mounts a focused card (for example `PermissionView`) and a focused chip, and reads that both use the EditorKit focus API (an environment or an accessibility value that EditorKit exposes, or the modifier type). (`FocusLookTests`: RED: 6 focus tests failed against an empty key. GREEN: 9 of 9 pass.)
- [x] `HOME=$(mktemp -d) swift test` passes with 0 failures and 0 warnings. Gallery images for review (light and dark) after the change. (The root swift test on main 0f3778df: 1829 + 59 passed. The gallery images are not made yet. The gallery runs after the Testudo hold.) Gallery (2026-11-26, main a7dd9878, EK 474081e5): ScreenshotTests 46 tests passed. Images in /Users/wballard/Library/Caches/AgentViewKit/screenshot-check/generated/HostedSnapshotTests/ (states-permission, states-elicitation-tab, elicitation-form, states-tool-call, light and dark). They show the one EK focus fill and no square ring. A temp HOME is not possible, because the harness refuses the HOME override.

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

## Review Findings (2026-11-26 00:23)

> Scope: `review sha 19fbb15e..0f3778df` — reviewed the diffs only — lines this change added or modified. 20 file(s) reviewed, 3 not reviewed.

> 3 file(s) not reviewed — no validator matched:
> - `Docs/decisions/focus-audit.md` — no validator matches this file
> - `Sources/AgentViewKitStyle/AgentViewKitStyle.docc/AgentViewKitStyle.md` — no validator matches this file
> - `plan.md` — no validator matches this file
