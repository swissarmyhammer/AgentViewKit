---
assignees:
- claude-code
position_column: todo
position_ordinal: a880
title: Give an AttachmentView preview that falls back to the chip the chip's ring corners
---
Found while working ^ars99rn. `AttachmentView` now passes `AttachmentChip.corners` (theme `radii.m`) to its attachment scope when its default renderer is the chip, and `.square` for a preview (image, pdf, text, code, audio, movie) or a registered view. A preview that cannot load its file (`LoadStateView` `.failed`) shows `AttachmentChip` in its place, but the scope is the outer `AttachmentView` scope (the inner chip makes no second scope, and `.scopeFocusRing` flows down the environment only), so the beacon ring of that fallback chip stays square while the chip draws rounded `radii.m` corners.

- [ ] Make the corners follow the load state, for example by lifting the load state of the preview so `AttachmentView` knows when the chip shows, or another mechanism that lets the shown surface pick the ring corners.
- [ ] Hosted test: an `AttachmentView` of an image file that does not decode lands nav focus on the beacon and its `drawFocusRingMask()` matches `RoundedRectangle(cornerRadius: radii.m)` (reuse `AttachmentFocusRingHostedTests` and `AgentItemFocusRingHostedTests.expectFocusRingMask(of:cornerRadius:)`).

#avk-7