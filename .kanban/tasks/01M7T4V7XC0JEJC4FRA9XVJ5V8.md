---
assignees:
- claude-code
position_column: todo
position_ordinal: '8480'
title: Search hits look up again when a prompt echo links to its local message (D207 f)
---
Found in ^de77446 (ACPClient `entry(forWireID:)` adoption).

Now: the transcript search driver (Sources/AgentViewKit/Thread/TranscriptSearch.swift) looks up the hits again when the session identity changes or when `transcript.count` changes. When the echo of a prompt arrives and links to the local user message, the count does not change. Thus a hit on that prompt that came before the link does not reveal or mark until the next new entry.

Do:
- Look up the hits again also when an entry gets its wire id (for example, observe a value that changes on the link, such as the set of wire ids of the transcript or a revision of the model). Choose the smallest certain signal, and do not look up on each streamed token.
- TDD unit test: hits that come before the echo of their prompt reveal and mark the local message when the echo links, with no new entry.

Run `swift test`. Push, and send the sha to testudoapp-9a.