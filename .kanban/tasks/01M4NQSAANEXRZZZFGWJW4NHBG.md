---
assignees:
- claude-code
position_column: todo
position_ordinal: '8680'
title: Remove the fixed vertical text size from the request cards of the thread
---
## What
`AgentThreadView` shows `PendingRequestsHost` in its non-scrolling area. These cards use `.fixedSize(horizontal: false, vertical: true)` on wrapped texts:

- `PermissionView`: the description text of the request.
- `ElicitationURLConsentView`: the URL text and the warning label.

A text with a fixed vertical size gives its full wrapped height at width 0 as its minimum height. Then the card is taller at its minimum size than at its usual width. In a `NavigationSplitView` column, this large minimum size goes to the window. Task ^nh1h15p found the same cause in `AgentAuthView`: it made the AgentViewKitDemo window min size 562 x 779 pt (124 pt without the card), and AgentViewKitDemo stopped with an `NSGenericException` constraint update loop in `SplitViewChildController.hostingView(_:didUpdateMinSize:maxSize:)`.

## Work
- [ ] For each card, write a hosted test: the minimum height (`NSHostingController.sizeThatFits(in: .zero)`) is not more than the height at a usual width.
- [ ] Remove the fixed vertical size from the texts of `PermissionView` and `ElicitationURLConsentView`, or give the texts another layout that keeps the minimum height small.
- [ ] Look for the same pattern in each other view that `AgentThreadView` shows outside the scroll view.