---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: A read-only thread with the composer of the host registers Send Message and Focus Composer
---
## What
Found during ^dzszz2p (`.threadComposer(placeholder:onSubmit:)`, TestudoApp D212). A read-only thread with the composer of the host shows the composer, but its scope registers no verb of the `compose` group (`AgentCommandTarget.registers(_:)` drops each `changesSession` verb when `session.isReadOnly`). Return in the editor submits, because `PromptInputView.submitCommand` falls back to a direct submit when `perform(.send)` returns `false`. But Send Message, Focus Composer and Mention… are not in the menus, the palette or the keys.

Work:
- [ ] Decide with the user whether the `compose` verbs register for a read-only thread with the composer of the host (`\.threadComposerRoute` is not `nil`). Stop, Approve, Reject and Fork stay absent.
- [ ] If yes: give the state to `AgentCommandTarget` through the mount of the scope (as `isSessionUnavailable`), and register the `compose` verbs.

## Tests
- [ ] Headless: with the composer of the host, the registry of a read-only thread has Send Message and Focus Composer; without it, it does not.
- [ ] `swift test` in the root: all pass, no code warnings. #d212