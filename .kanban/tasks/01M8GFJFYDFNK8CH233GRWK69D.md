---
assignees:
- claude-code
position_column: todo
position_ordinal: '8980'
title: Static message rows with a footer have a wrong height
---
Found in ^9ync5h3 (2026-11-28). `transcriptRowsHaveDefaultLook` does not look at `messageFooter`, and no chrome rule of `TranscriptRowChrome` has a footer. Thus in a host with a footer (the demo app sets `.messageFooter { MessageActions(entry:) }` in `SessionThreadColumn`), the cache gives each message row a height with no footer.

Probe (StaticRowHost, agent answer of one line, width 480, footer `MessageActions`): cache height 48 pt, static row 48 pt, real row 73 pt. The row jumps 25 pt when it becomes real, and the virtual stack places the rows below it at a wrong y.

## What
- [ ] Decide how a footer enters the height: no cache for a thread with a footer, or a chrome rule for a footer of a known height (for example a kit footer API for `MessageActions`, whose height the probe measures).
- [ ] When the footer has a rule, give the flat form of a message a chrome line for it (`TranscriptChromeLine`), so a message with `MessageActions` is one flat view while the rows move (today it keeps the views of its real row).

## Tests
- [ ] Unit test: a message row with a footer has the same height in its static form and in its real form.

#perf