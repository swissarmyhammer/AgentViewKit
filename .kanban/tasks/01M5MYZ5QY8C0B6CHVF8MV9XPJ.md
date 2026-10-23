---
assignees:
- claude-code
position_column: todo
position_ordinal: b080
title: DefaultThreadComposer takes EditorKit prefix-completion routes (one modifier or init parameter)
---
Requested by testudoapp-2c (2026-10-23) for Testudo card ^6nkvrk1. Needs EditorKit ^fe1dbrc (main 7944113, code a5f50d3): `PrefixCompletionSource(routes:)`, `PrefixCompletionRoute(sigil, provider:)`, `Autocomplete(sources: [.prefixed(source)])`, `CompletionResult.isRanked`, Tab accepts an open completion. The wiring is in EditorKit's DocC article "Prefix completions".

Testudo supplies only the providers: @ files, ^ tasks, # tags, / commands. AVK owns the rest, with no host glue, so Testudo never calls `request` itself:
- [ ] A public API on `DefaultThreadComposer`: ONE modifier (e.g. `.composerCompletions([PrefixCompletionRoute])`) or ONE init parameter (e.g. `completionRoutes:`). PROPOSE the shape in a comment and send it to testudoapp-2c BEFORE pushing.
- [ ] Autocomplete wiring inside the composer: `PrefixCompletionSource` over the host routes.
- [ ] Call `completion.request(trigger: .typed, …)` after each typed edit, as the DocC snippet shows.
- [ ] Popup placement at the caret of the composer, inside the floating glass bottom bar (no glass on glass).
- [ ] Return and Tab accept an open completion; accepting is ONE undo entry on the window stack.
- [ ] No routes means no completions, as today.
- [ ] Decide how the routes relate to AVK's own `FileReferenceSource` and `SlashCommandSource` (Input/). EditorKit suggests they could fold into routes. Write down the decision in a comment; don't fold them unless the API needs it.

EditorKit API change to check when updating to 7944113: `CompletionTokenOpening` gained `body` and `anchor` (default `.tokenStart`); openings match only at token start; `SmartTagCompletionSource` / `.smartTags` were removed (AVK has no uses). editorkit-28 built AVK against it, but didn't run the AVK tests, so watch the completion tests.

Tests (hosted): typing each sigil opens the popup with the route's items; Return accepts and Tab accepts; one undo takes the whole accepted completion out; no routes, no popup; the popup sits at the caret. Full `swift test` green; the demo builds.

Queue: after ^8zmkh1a, ^2sg9taf, ^p6e0v5w, ^bkhgxs5. Send testudoapp-2c the SHA when it's done. #avk-8 #testudo-request #cross-repo