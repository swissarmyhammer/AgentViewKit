---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m621gher7s9zbabx8nvr1865
  text: |-
    ### review — clean
    - evidence: review sha cf88bff..8ac8193 — counts findings 0, confirmed 0, refuted 0 (14 attempted, 0 failed); 42 files reviewed, Sources/AgentViewKit/Resources/Localizable.xcstrings not reviewed (no validator matches). Five code-hygiene tool rules declined Sources/AgentViewKit/Input/ObservationReport.swift because the commit deletes it.
    - work items checked: EditorKit resolves to 14abdc9, which descends from 9edc257, and every .navScrollable/.scopeFocusRing chains after .commandScope; the four List uses replaced by AgentRowList; Return/double-click, nav keys, VoiceOver, jump labels kept; NoSwiftUIListTests scans with SourceScanning; hosted arrow/Return/Escape/jump tests plus the regenerated review gallery.
    - left unchecked: `swift test` and Scripts/test-examples.sh are green — test-examples.sh still fails on the known editor.isHittable test.
    - next: none; card moved to done.
  timestamp: 2026-10-28T19:59:05.688516+00:00
- actor: claude-code
  id: 01m621h8awvxxy940ysjj497dx
  text: |-
    ### finish — clean review, held in review (moved back from done)
    - implement: changed. 8ac8193 on wt/list, merged into main as 764c35b.
    - test: on main, swift test 1907 + 288 + 37 + 1 passed, 0 skipped. test-examples.sh fails only on the known ACPTabEndToEndTests editor.isHittable test.
    - review: clean (0 findings, 42 files).
    - Held: the acceptance item "swift test and Scripts/test-examples.sh are green" is unchecked until EditorKit ^sva41w0 (out-of-process hit test) makes the editor hittable. Same blocker as ^j4vnh1r. When it lands, re-run test-examples.sh, check the item, and close.
    - User decision recorded: selection follows the window's single keyboard focus, so only the focused list shows a selected row. No per-list inactive selection.
  timestamp: 2026-10-28T19:59:29.116346+00:00
position_column: review
position_ordinal: '8180'
title: 'No SwiftUI List in AVK: the session list and connections become ScrollView + LazyVStack, with selection and keys from EditorKit nav'
---
EditorKit ^7wt12an (EditorKit main 9edc257) applied the user's decision: no SwiftUI List anywhere. OutlineView, DiagnosticsList, ProgressOperationsList and TouchCommandPalette are now ScrollView + LazyVStack. Selection and the arrow, Return and Escape keys come from command scopes and `nav.*`, not from native List behaviour. AVK applies the same rule.

AVK has these List uses:
- Sources/AgentViewKit/Sessions/SessionListView.swift:223 `List {`
- Sources/AgentViewKit/Connections/ConnectionsView.swift:22 `List(session.mcpServers)`
- Sources/AgentViewKit/Connections/ConnectionRow.swift:87, a preview
- Examples/AgentViewKitDemo/AgentViewKitDemoFeature/GalleryTabView.swift:243 `List(DemoConnectionState.allCases…)`

## Work
- [x] Bump EditorKit to 9edc257 or later. Breaking change: `.navScrollable` and `.scopeFocusRing` must chain after `.commandScope`. AVK's AgentItemScope.swift:58-60 and AgentControlScope.swift:67-69 already do; check there are no other places.
- [x] Replace each List with ScrollView + LazyVStack. Rows are command scopes; selection, arrows, Return and Escape go through EditorKit nav and jump, the way EditorKit's OutlineView now does it. Selection draws with `.selectionSurface`, with accent only for selection and focus. Transparent by default. Row padding and gap come from the theme.
- [x] Keep the current behaviour: open a session on Return or double-click, keyboard navigation, VoiceOver row reading, and jump labels on the rows
- [x] A package-structure test forbids `List(` and `List {` in the kit, demo support and demo, as a whole-word token. Use EditorKit's shared style scanner (^3q7j9nd) if it has landed; otherwise use SourceScanning.
- [x] Hosted tests: arrow selection, Return opens, Escape clears, jump to a row. Re-record the snapshots.
- [ ] `swift test` and Scripts/test-examples.sh are green