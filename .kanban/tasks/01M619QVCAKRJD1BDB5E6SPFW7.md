---
assignees:
- claude-code
position_column: todo
position_ordinal: ad80
title: 'No SwiftUI List in AVK: the session list and connections become ScrollView + LazyVStack, with selection and keys from EditorKit nav'
---
EditorKit ^7wt12an (EditorKit main 9edc257) applied the user's decision: no SwiftUI List anywhere. OutlineView, DiagnosticsList, ProgressOperationsList and TouchCommandPalette are now ScrollView + LazyVStack. Selection and the arrow, Return and Escape keys come from command scopes and `nav.*`, not from native List behaviour. AVK applies the same rule.

AVK has these List uses:
- Sources/AgentViewKit/Sessions/SessionListView.swift:223 `List {`
- Sources/AgentViewKit/Connections/ConnectionsView.swift:22 `List(session.mcpServers)`
- Sources/AgentViewKit/Connections/ConnectionRow.swift:87, a preview
- Examples/AgentViewKitDemo/AgentViewKitDemoFeature/GalleryTabView.swift:243 `List(DemoConnectionState.allCases…)`

## Work
- [ ] Bump EditorKit to 9edc257 or later. Breaking change: `.navScrollable` and `.scopeFocusRing` must chain after `.commandScope`. AVK's AgentItemScope.swift:58-60 and AgentControlScope.swift:67-69 already do; check there are no other places.
- [ ] Replace each List with ScrollView + LazyVStack. Rows are command scopes; selection, arrows, Return and Escape go through EditorKit nav and jump, the way EditorKit's OutlineView now does it. Selection draws with `.selectionSurface`, with accent only for selection and focus. Transparent by default. Row padding and gap come from the theme.
- [ ] Keep the current behaviour: open a session on Return or double-click, keyboard navigation, VoiceOver row reading, and jump labels on the rows
- [ ] A package-structure test forbids `List(` and `List {` in the kit, demo support and demo, as a whole-word token. Use EditorKit's shared style scanner (^3q7j9nd) if it has landed; otherwise use SourceScanning.
- [ ] Hosted tests: arrow selection, Return opens, Escape clears, jump to a row. Re-record the snapshots.
- [ ] `swift test` and Scripts/test-examples.sh are green