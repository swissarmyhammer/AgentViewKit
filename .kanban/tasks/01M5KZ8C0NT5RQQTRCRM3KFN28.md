---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5m085mqj63evh2bk8zhj1k5
  text: 'UNBLOCKED: EditorKit f05dabb on main (^twfbzd4; main commit e63dc69) has `CommandSystem.mount(at:by:register:)` / `unmount(at:by:unregister:)`. ScopeMountHolders'' old methods are untouched. EditorKit holds ^f2yzy57 (which makes them internal) until this migration is on AVK main; tell editorkit-28 when it is.'
  timestamp: 2026-10-23T09:07:40.823925+00:00
position_column: todo
position_ordinal: aa80
title: Migrate agent command and attachment mounts to EditorKit CommandSystem.mount/unmount (hand-back when a window closes)
---
Requires EditorKit ^twfbzd4 on EditorKit origin/main. Check for `CommandSystem.mount(at:by:register:)` first; if it's missing, record that the card is waiting, and stop. Full migration notes are on EditorKit card ^twfbzd4 (from editorkit-28, 2026-10-23).

Why: with two windows at one path, closing the newer window should hand the path back to the remaining window's mount at once. Today the remaining AgentCommandMount / AgentAttachmentMount re-registers only on its next update (^32a58sq uses `mountHolders.hold/isHeld/release`). Later, EditorKit ^f2yzy57 makes the old ScopeMountHolders methods internal, so this migration is required.

New API (EditorCommandsUI):
```
extension CommandSystem {
  public func mount(at path: FocusPath, by holder: AnyObject, register: @escaping @MainActor (inout CommandRegistry) -> Void)
  public func unmount(at path: FocusPath, by holder: AnyObject, unregister: @escaping @MainActor (inout CommandRegistry) -> Void)
}
```
The newest holder registers. When it unmounts and an older holder remains, the hand-back runs on the next main run-loop pass, never during SwiftUI teardown: the leaving mount's unregister, then the remaining mount's register. When the last holder unmounts, it unregisters at once.

Work, in AgentCommandScope.swift (AgentCommandMount); AgentAttachmentScope.swift and AgentCommandsTests.swift follow the same pattern:
- register(heldBy:): replace the register + `mountHolders.hold(at:by:)` pair with `scope.system.mount(at: scope.path, by: coordinator) { [target, path = scope.path, groupsOff = scope.groupsOff] registry in AgentCommandRegistration.register(target, at: path, into: &registry, groupsOff: groupsOff) }`.
- updateNSView: drop the `isHeldByANewerMount` guard, and call register(heldBy:) on every update.
- dismantleNSView: `if let r = coordinator.registration { r.system.unmount(at: r.path, by: coordinator) { registry in AgentCommandRegistration.deregister(at: r.path, from: &registry) } }`.
- Decide whether deregister should also unregister the verbs (today it removes only the `.host` part), and record why.
- Remove every remaining use of `mountHolders` in AVK.

Tests:
- The ^32a58sq hosted test (rebuilding the thread view under a new identity keeps the commands) stays green.
- New hosted test: two windows (offscreen harness windows) host a thread at the SAME path; close the newer one; after the next main run-loop pass, the remaining window's commands are available and perform. The same for an attachment scope.
- Full `swift test` green. #avk-7 #cross-repo