---
assignees:
- claude-code
position_column: todo
position_ordinal: a480
title: 'AVK-8 review gallery: make the dark images of sidebar lists, inspector forms and controls on glass show the dark look (found by ^8q34yt8)'
---
Found while building the review gallery of ^8q34yt8 (2026-10-27). This is a limit of the test render path, not a kit finding.

The review gallery and the hosted snapshot tests render with path A of `ViewSnapshot` (the cache of a hidden window). In the dark variant, some parts do not take the dark look:
- A SwiftUI `List` in a `NavigationSplitView` sidebar draws black text on the dark sidebar (`gallery--dark.png`: the session list rows, 1.2:1). A plain `Text` in the same sidebar is light, so only `List` rows are affected.
- A grouped `Form` in a SwiftUI `.inspector` draws white rows with black text (`inspector--dark.png`: the top 350 points of the attachment inspector). The same form in an `HStack` is dark.
- A `.glass` button draws a black label (`Show Error`, `Sign In`, the suggestion chips, the pill), and a `.bordered` button on the floating glass of the bar deck draws a white bezel (`request-deck--dark.png`; the recorded `request-deck-bar-dark.png` has the same).
- The symbol-only glass buttons of the composer accessory row (mic, Send) are not drawn at all, in light and dark (the recorded `composer-idle-*.png` has the same).
Probes with plain SwiftUI views (no kit code) gave the same results, so the cause is the render path.

Files: `Sources/AgentViewKitTestSupport/ViewSnapshot.swift`, `Sources/AgentViewKitTestSupport/SnapshotVariant.swift`.

What to change: find a way to give the AppKit-hosted parts the appearance of the variant (for example the appearance of the hosting view and of each split view item, set before the first render), or document each limit on the contact sheet. Keep the variants in process: no system setting.

Deterministic test: hosted tests render, in the dark variant, `NavigationSplitView { List { Text("Row") } } detail: { Text("Detail") }` and `Color.clear.inspector(isPresented: .constant(true)) { Form { Section { Text("Name") } }.formStyle(.grouped) }`, and require that the text color has a contrast of at least 4.5:1 with its background. No clock and no wait.
#avk-8