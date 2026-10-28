---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m61dd69w4cb7raactx97ac56
  text: |-
    ### review — stuck
    - evidence: review sha 0e80f75..a36c815 — counts findings 0, confirmed 0, refuted 1, attempted 14, failed 0. 22 files reviewed; 32 deleted PNGs and README.md/plan.md not reviewed. Five code-hygiene tool rules (disallowed-constructs-swift, function-length-swift, idioms-swift, magic-numbers-swift, missing-docs-swift) declined Tests/PackageStructureTests/LightAndDarkOnlyTests.swift: the file exists only at a36c815, not in the main working tree they read.
    - acceptance: items 1-3 checked against a36c815 (git grep and git ls-tree). "swift test is green" left unchecked: 1 skip and 1 warning, and green means zero of each.
    - next: a person decides how to run the five rules on LightAndDarkOnlyTests.swift (re-run review sha 0e80f75..a36c815 once wt/rtic-removal is checked out or merged here), then /review ^ffeg9my again. Card stays in review.
  timestamp: 2026-10-28T14:07:44.444699+00:00
- actor: claude-code
  id: 01m61jnvgz267qb0kvdswx5zkr
  text: |-
    ### HANDOFF (2026-10-28)
    - State: in review. The work is done on worktree branch `wt/rtic-removal` (worktree /Users/wballard/github/swissarmyhammer/AgentViewKit-wt/rtic). Commits:
      - 73cf2b9: the removal, 32 PNGs deleted.
      - a36c815: plan.md and README say no manual check.
      - 595044f: the demo's Increased Contrast look removed (user decision), and LightAndDarkOnlyTests also scans the demo.
    - Tests: swift test passed 1893 + 267 + 1, 0 failures, 0 skips. test-examples.sh fails only on the known editor.isHittable test.
    - The earlier review was incomplete, because the code-hygiene rules read the main tree and skipped LightAndDarkOnlyTests.swift.
    - Next, with main clean and after the leak branch merges:
      1. `git merge --no-ff wt/rtic-removal`
      2. `/review <this card> <merge-base>..HEAD` in main
      3. If clean, move to done, then remove the worktree and the branch.
    - Also seen: Scripts/test-examples.sh once hung for about 50 minutes, because its own time limit never fired. That's worth a card.
  timestamp: 2026-10-28T15:39:51.199072+00:00
position_column: review
position_ordinal: '8280'
title: Remove every Reduce Transparency and Increase Contrast test; snapshots are light and dark only
---
User decision (2026-10-28), from the question about rule 9 of EditorKit/style.md: "Remove all RT/IC tests". This covers glass checks and also kit-logic contrast checks such as the terminal ANSI grey remap. The same decision goes to KanbanViewKit (^mvbb914 there), EditorKit and TestudoApp.

## Scope
- GlassAccessibilityTests (Tests/AgentViewKitTests/Theme): delete.
- The Reduce Transparency and Increase Contrast snapshot variants: remove them from the variant lists (SnapshotFixtures / SnapshotVariant), and delete the 22 RT/IC PNGs in Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests.
- Every test that sets `accessibilityReduceTransparency`, `colorSchemeContrast` / increase contrast or reduce transparency. Today that's ArtifactViewSurfaceHostedTests, GlassRenderProbeTests, ContentEdgeHostedProbe, AttachmentInspectorFormHostedTests, SessionNoticeBannerSurfaceHostedTests, TranscriptEntrySurfaceHostedTests, StatusBarSurfaceHostedTests, KitSurfaceRenderTests, PermissionViewSurfaceHostedTests, ViewSnapshotTests, TerminalContrastHostedTests, and any others `rg -n "ReduceTransparency|reduceTransparency|colorSchemeContrast|increaseContrast|IncreaseContrast" Tests` finds. Remove the RT/IC cases and keep the light and dark ones. Delete any test helper that only existed for RT/IC.
- Docs: in plan.md, change the "Accessibility" section (:255), the bottom-bar-buttons snapshot description (:247), and the TerminalContrastHostedTests mention (:243) to light and dark only, citing EditorKit/style.md rule 9.
- No compatibility shims. Don't leave dead enum cases behind.

## Acceptance
- [x] `rg -n "ReduceTransparency|reduceTransparency|colorSchemeContrast|increaseContrast|IncreaseContrast|reduce-transparency|increase-contrast" Tests Sources Examples` finds nothing that a test sets or names, apart from kit code that legitimately reads the environment
- [x] No RT/IC PNGs remain under __Snapshots__
- [x] A package-structure test fails if a test sets either setting again
- [ ] `swift test` is green

## Review Findings (2026-10-28 09:04)

> Scope: `review sha 0e80f75..a36c815` — reviewed the diffs only — lines this change added or modified. 22 file(s) reviewed, 34 not reviewed.

> 32 file(s) not reviewed — the file holds no text to review:
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/GlassSnapshotTests/composer-field-idle-increase-contrast.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/GlassSnapshotTests/composer-field-idle-reduce-transparency.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/GlassSnapshotTests/composer-field-running-increase-contrast.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/GlassSnapshotTests/composer-field-running-reduce-transparency.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/GlassSnapshotTests/floating-controls-increase-contrast.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/GlassSnapshotTests/floating-controls-reduce-transparency.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/GlassSnapshotTests/request-deck-bar-increase-contrast.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/GlassSnapshotTests/request-deck-bar-reduce-transparency.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/GlassSnapshotTests/thread-header-increase-contrast.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/GlassSnapshotTests/thread-header-reduce-transparency.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/bottom-bar-buttons-increase-contrast.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/bottom-bar-buttons-reduce-transparency.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/code-block-increase-contrast.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/code-block-reduce-transparency.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/composer-idle-increase-contrast.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/composer-idle-reduce-transparency.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/composer-running-increase-contrast.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/composer-running-reduce-transparency.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/elicitation-form-increase-contrast.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/elicitation-form-reduce-transparency.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/permission-card-increase-contrast.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/permission-card-reduce-transparency.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/request-deck-bar-increase-contrast.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/request-deck-bar-reduce-transparency.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/session-notice-increase-contrast.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/session-notice-reduce-transparency.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/status-banner-increase-contrast.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/status-banner-reduce-transparency.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/terminal-increase-contrast.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/terminal-reduce-transparency.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/thread-increase-contrast.png` — not UTF-8 text, so there is nothing to review
> - `Tests/AgentViewKitTests/Snapshots/__Snapshots__/HostedSnapshotTests/thread-reduce-transparency.png` — not UTF-8 text, so there is nothing to review

> 2 file(s) not reviewed — no validator matched:
> - `README.md` — no validator matches this file
> - `plan.md` — no validator matches this file

> ⚠️ tool rule 'code-hygiene/disallowed-constructs-swift' declined an item — it judged the rest of the code, and this it could not judge:
> disallowed-constructs-swift found no file at Tests/PackageStructureTests/LightAndDarkOnlyTests.swift, so its constructs are unread

> ⚠️ tool rule 'code-hygiene/function-length-swift' declined an item — it judged the rest of the code, and this it could not judge:
> function-length-swift found no file at Tests/PackageStructureTests/LightAndDarkOnlyTests.swift, so its bodies are unread

> ⚠️ tool rule 'code-hygiene/idioms-swift' declined an item — it judged the rest of the code, and this it could not judge:
> idioms-swift found no file at Tests/PackageStructureTests/LightAndDarkOnlyTests.swift, so its declarations are unread

> ⚠️ tool rule 'code-hygiene/magic-numbers-swift' declined an item — it judged the rest of the code, and this it could not judge:
> magic-numbers-swift found no file at Tests/PackageStructureTests/LightAndDarkOnlyTests.swift, so its literals are unread

> ⚠️ tool rule 'code-hygiene/missing-docs-swift' declined an item — it judged the rest of the code, and this it could not judge:
> missing-docs-swift found no file at Tests/PackageStructureTests/LightAndDarkOnlyTests.swift, so its declarations are unread

## Blocker (2026-10-28 09:04)
- [ ] The review is incomplete: five code-hygiene tool rules (disallowed-constructs-swift, function-length-swift, idioms-swift, magic-numbers-swift, missing-docs-swift) read files from the main working tree, and Tests/PackageStructureTests/LightAndDarkOnlyTests.swift exists only at a36c815 (branch wt/rtic-removal), so those rules never judged the one new Swift file in the change. A person must decide how to run them on it: re-run `review sha 0e80f75..a36c815` with wt/rtic-removal checked out (or merged) in this repository, then re-review this card.
- `swift test` is green stays unchecked: the worktree run had 0 failures but 1 skip (`theGeneratedDemoProjectPinsTheRootACPRevisions`) and 1 warning (mlx-swift_Cmlx packaging), and the green contract is zero failures, zero warnings, zero skipped.