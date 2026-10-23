---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5neg2pd8dpjnyzpzw2f2bmv
  text: |-
    Research (implement pickup):
    - EditorKit resolved at 69d04fc (.build/checkouts/EditorKit). EditorComplete is unchanged between 69d04fc and the sibling checkout's d4d057c, so the DocC "Prefix completions" article and PrefixCompletionSource/Route/Autocomplete sources read there match what AVK links.
    - AVK already builds with the ^fe1dbrc API (CompletionTokenOpening body/anchor; no SmartTagCompletionSource uses).
    - EditorView (EditorSwiftUI) already accepts an open completion on Return (handleReturn gate before the host hook) and on Tab (bindTabAccept), each as ONE transaction via model.dispatch. AVK needs no key code of its own.
    - The composer menu pipeline exists: EditorKitPromptEditor publishes PromptEditorMenu via PromptEditorMenuKey; PromptInputView draws it in PromptEditorMenuLayer on its own floating glass (.editorMenu), a sibling of the field glass in the one container (D110 (c)), so no glass on glass, and the list itself (CompletionSuggestionsList + PromptCompletionRow) has no fill except the selected-row .selection tint. Today the menu's leading edge is the editor's leading edge, not the caret.
    - EditorKit has no public SwiftUI caret geometry. The input view is a real NSTextView (EditorInputTextView, TextKit 2), so NSTextInputClient.firstRect(forCharacterRange:actualRange:) gives the caret rect.
    - CompletionTokenizer.claim is internal; CompletionTokenizer.openedToken(line:caret:opening:) is public and is what the composer can use to gate requests per route opening.
    - After an accept, the current code re-requests completion (for `@dir/`). A route row that keeps the caret in its token (FileMentionProvider inserts `@path` with no trailing space) would reopen the popup and the next Return would accept again instead of sending. The re-request must stay limited to an accept that ends in `/`.
  timestamp: 2026-10-23T22:35:54.445262+00:00
- actor: claude-code
  id: 01m5neg9rx6mzrrjh9aeermvvn
  text: |-
    PROPOSED PUBLIC API (for testudoapp-2c; relay before any push) — ONE modifier:

    ```swift
    import EditorComplete

    extension View {
      /// Sets the prefix-completion routes of the EditorKit editor of the composer below this view.
      public func composerCompletions(_ routes: [PrefixCompletionRoute]) -> some View
    }
    ```

    Host use (no host glue; Testudo never calls `request`):

    ```swift
    AgentThreadView(session: session, connection: connection)
      .composerCompletions([
        PrefixCompletionRoute("@", provider: FileMentionProvider(index: files)),
        PrefixCompletionRoute("^", provider: tasks),
        PrefixCompletionRoute("#", provider: tags),
        PrefixCompletionRoute("/", anchor: .lineStart, provider: commands),
      ])
    ```

    Why the modifier and not `completionRoutes:` on `DefaultThreadComposer.init`: the convenience `AgentThreadView(session:connection:sessionTitle:headerContextMenuPath:)` builds the `DefaultThreadComposer` itself. An init parameter would make Testudo switch to the composer-slot init, or would need a second parameter on `AgentThreadView.init` (two APIs). The modifier is one API, is read through the environment like `.promptFileRoot(_:)`, and works on any ancestor of the composer: `AgentThreadView`, `DefaultThreadComposer`, or a `PromptInputView` with the EditorKit editor. An empty list (the default) is today's behaviour: no route completions.

    AVK does the rest inside the composer: a `PrefixCompletionSource` over the routes, composed with `editorExtensions { Autocomplete(sources: [.prefixed(source)]) }`, `completion.request(trigger: .typed, …)` after each typed edit in a route token, the popup at the caret in the bottom bar, and Return/Tab accept (one undo entry on the window stack). The kit keeps one `PrefixCompletionSource` per editor and sets `routes` when the host gives a new list, so a new route list takes effect on the next keystroke.
  timestamp: 2026-10-23T22:36:01.693470+00:00
- actor: claude-code
  id: 01m5negf6whqx526sydh4grsg1
  text: |-
    DECISION — routes vs AVK's own FileReferenceSource and SlashCommandSource: NOT folded into routes. The API does not need it.

    - Both kit sources stay as they are, with their own behaviour: `/` lists `SessionModel.availableCommands` with the "No commands" note; `@` lists the entries under `.promptFileRoot` and makes an accepted file a chip whose `link` the composer sends as an attachment.
    - A host route takes its sigil from the kit: a route whose sigil is `/` replaces SlashCommandSource (and its "No commands" note) in that composer; a route whose sigil is `@` replaces FileReferenceSource (and the file chips). Routes with other sigils (`^`, `#`, …) sit beside both kit sources.
    - Why: two sources on one sigil would list mixed rows for one token, and the engine's tie rule (first declared opening) would pick whose token it is by source order, not by intent. Folding the kit sources into routes would change their rows, ranking, chips and the no-commands note for hosts that give no routes, which this card does not ask for.
    - Consequence for Testudo: its `/` route owns the whole `/` menu, so if it wants the agent's slash commands in it, its provider reads `SessionModel.availableCommands` itself. Its `@` route owns `@`; a `@path` it accepts is plain text (no chip, no attachment link) unless a later card asks for that.
  timestamp: 2026-10-23T22:36:07.260427+00:00
- actor: claude-code
  id: 01m5ng6wtf3an8faphgcyxn5q1
  text: |-
    Implementation landed (not committed):
    - Public API, final: `extension View { public func composerCompletions(_ routes: [PrefixCompletionRoute]) -> some View }` (Sources/AgentViewKit/Input/ComposerCompletions.swift). The environment entry `composerCompletionRoutes` is internal. No other public symbol was added or changed; `DefaultThreadComposer.init()` is unchanged, and the new `DefaultThreadComposer.init(editorSession:)` is internal (test seam, same pattern as `EditorKitPromptEditor.init(context:session:)`).
    - Wiring (EditorKitPromptEditor / PromptEditorSession): one `PrefixCompletionSource` per editor session; `engine(commands:root:routes:)` sets its `routes` on each request and rebuilds the `CompletionEngine` only when commands, root or the route sigils change; the route source is composed with `editorExtensions { Autocomplete(sources: [.prefixed(source)]) }.completionSources` beside the kit sources. A `/` route drops `SlashCommandSource` (and the "No commands" note); an `@` route drops `FileReferenceSource` (and the chips/links).
    - Request: after each typed edit (`.input`/`.delete`) the composer calls `request(trigger: .typed, …)` when the caret is in a kit trigger token OR a route token (`CompletionTokenizer.openedToken` per route opening), and dismisses otherwise. Gating, rather than requesting on every keystroke, keeps no empty session open, so a plain Return still sends.
    - After an accept the composer re-requests only when the line ends in `/` (directory); any other accept dismisses, so the next Return sends (`^a1b2c3d` would otherwise reopen the popup).
    - Placement: `PromptCaretProbe` (new, Sources/AgentViewKit/Input/PromptCaretProbe.swift) sits behind the editor and finds the editor's NSTextView; `PromptCaretLocator.caretOffset()` reads `firstRect(forCharacterRange: selectedRange())`. `PromptEditorMenu` gained `caretOffset` and `width`; `PromptEditorMenuLayer` puts the leading edge at the caret, clamped inside the field. The menu stays on its one sibling `.editorMenu` glass above the field glass (no glass on glass) and adds no fill.
    - Return/Tab: EditorKit's EditorView already accepts an open session on both keys as one dispatched transaction; the hosted tests confirm it is one window-stack entry.
    - TDD: RED 1 = the new suite did not compile (no `composerCompletions`, no `DefaultThreadComposer(editorSession:)`); RED 2 = with the API stubbed and no wiring, `anAcceptKeyInsertsTheSelectedRow` never got the route rows (killed at 150 s; normal run < 1 s); `withNoRoutesASigilOpensNoPopup` passed at once (it guards today's behaviour). GREEN = 8 tests / 12 cases in ComposerCompletionRoutesHostedTests pass in 3 s.
    - Callers updated for the changed internal signatures: GlassAccessibilityTests (PromptEditorMenu init), SlashCommandSourceTests (engine(commands:root:routes:)), a comment in EditorKitPromptEditorHostedTests.
    - Snapshots: none re-recorded; no snapshot changed.
    - Discovery: `kanban` write ops in this session return the whole board (~110 KB) as their result; the writes still land.
  timestamp: 2026-10-23T23:05:50.671964+00:00
- actor: claude-code
  id: 01m5ng71bjfqw1syx03ser859e
  text: |-
    ### implement — changed
    - evidence: `swift test` → 1752 tests in 216 suites passed (3 known issues are the pre-existing `withKnownIssue` harness self-tests), PackageStructureTests 227 passed, 0 compiler warnings; `xcodebuild -project Examples/AgentViewKitDemo/AgentViewKitDemo.xcodeproj -scheme AgentViewKitDemo build` → BUILD SUCCEEDED (no UI run, so the UI-test lock was not taken). Files: Sources/AgentViewKit/Input/ComposerCompletions.swift (new), Sources/AgentViewKit/Input/PromptCaretProbe.swift (new), Sources/AgentViewKit/Input/EditorKitPromptEditor.swift, Sources/AgentViewKit/Input/PromptInputView.swift, Sources/AgentViewKit/Input/DefaultThreadComposer.swift, README.md, Tests/AgentViewKitTests/Input/ComposerCompletionRoutesHostedTests.swift (new), Tests/AgentViewKitTests/Theme/GlassAccessibilityTests.swift, Tests/AgentViewKitTests/Input/SlashCommandSourceTests.swift, Tests/AgentViewKitTests/Input/EditorKitPromptEditorHostedTests.swift.
    - next: /review; relay the API comment to testudoapp-2c before any push; send the SHA after commit.
  timestamp: 2026-10-23T23:05:55.314820+00:00
position_column: doing
position_ordinal: '8380'
title: DefaultThreadComposer takes EditorKit prefix-completion routes (one modifier or init parameter)
---
Requested by testudoapp-2c (2026-10-23) for Testudo card ^6nkvrk1. Needs EditorKit ^fe1dbrc (main 7944113, code a5f50d3): `PrefixCompletionSource(routes:)`, `PrefixCompletionRoute(sigil, provider:)`, `Autocomplete(sources: [.prefixed(source)])`, `CompletionResult.isRanked`, Tab accepts an open completion. The wiring is in EditorKit's DocC article "Prefix completions".

Testudo supplies only the providers: @ files, ^ tasks, # tags, / commands. AVK owns the rest, with no host glue, so Testudo never calls `request` itself:
- [x] A public API on `DefaultThreadComposer`: ONE modifier (e.g. `.composerCompletions([PrefixCompletionRoute])`) or ONE init parameter (e.g. `completionRoutes:`). PROPOSE the shape in a comment and send it to testudoapp-2c BEFORE pushing.
- [x] Autocomplete wiring inside the composer: `PrefixCompletionSource` over the host routes.
- [x] Call `completion.request(trigger: .typed, …)` after each typed edit, as the DocC snippet shows.
- [x] Popup placement at the caret of the composer, inside the floating glass bottom bar (no glass on glass).
- [x] Return and Tab accept an open completion; accepting is ONE undo entry on the window stack.
- [x] No routes means no completions, as today.
- [x] Decide how the routes relate to AVK's own `FileReferenceSource` and `SlashCommandSource` (Input/). EditorKit suggests they could fold into routes. Write down the decision in a comment; don't fold them unless the API needs it.

EditorKit API change to check when updating to 7944113: `CompletionTokenOpening` gained `body` and `anchor` (default `.tokenStart`); openings match only at token start; `SmartTagCompletionSource` / `.smartTags` were removed (AVK has no uses). editorkit-28 built AVK against it, but didn't run the AVK tests, so watch the completion tests.

Tests (hosted): typing each sigil opens the popup with the route's items; Return accepts and Tab accepts; one undo takes the whole accepted completion out; no routes, no popup; the popup sits at the caret. Full `swift test` green; the demo builds.

Queue: after ^8zmkh1a, ^2sg9taf, ^p6e0v5w, ^bkhgxs5. Send testudoapp-2c the SHA when it's done. #avk-8 #testudo-request #cross-repo