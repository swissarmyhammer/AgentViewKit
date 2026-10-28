---
assignees:
- claude-code
position_column: todo
position_ordinal: a980
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
- [ ] `rg -n "ReduceTransparency|reduceTransparency|colorSchemeContrast|increaseContrast|IncreaseContrast|reduce-transparency|increase-contrast" Tests Sources Examples` finds nothing that a test sets or names, apart from kit code that legitimately reads the environment
- [ ] No RT/IC PNGs remain under __Snapshots__
- [ ] A package-structure test fails if a test sets either setting again
- [ ] `swift test` is green