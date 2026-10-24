#import "ExceptionCatchingWindow.h"

/// The AppKit methods that mark a window as needing another pass of its
/// display cycle.
///
/// The methods are not public. Each one throws the `NSGenericException` of
/// a loop of its pass. The exception can come in a layout pass, and the
/// layout code of AppKit stops the process on an exception
/// (`+[NSApplication _crashOnException:]`). A catch in a public method of the
/// window, such as `updateConstraintsIfNeeded`, is too late for that path.
/// Thus the window catches the exception where AppKit throws it.
@interface NSWindow (DisplayCycleMarks)
- (void)_postWindowNeedsUpdateConstraints;
- (void)_postWindowNeedsLayout;
- (void)_postWindowNeedsDisplay;
@end

@implementation ExceptionCatchingWindow

+ (BOOL)appKitHasTheMarkMethods {
  return [NSWindow instancesRespondToSelector:@selector(_postWindowNeedsUpdateConstraints)]
      && [NSWindow instancesRespondToSelector:@selector(_postWindowNeedsLayout)]
      && [NSWindow instancesRespondToSelector:@selector(_postWindowNeedsDisplay)];
}

/// Runs `mark`, and keeps the reason of an exception of the mark.
///
/// AppKit throws the exception of a loop after it logged the loop. The catch
/// keeps the exception in the pass, so that the layout code of AppKit does
/// not stop the process. After the exception, the window drops each mark,
/// so that the loop ends and the main run loop goes on. The run loop of an
/// application ends the loop in the same way: the exception ends the display
/// cycle of the window.
///
/// - Parameter mark: The call of the mark method of the superclass.
- (void)catchExceptionOfMark:(void(NS_NOESCAPE ^)(void))mark {
  if (_caughtExceptionReason != nil) {
    return;
  }
  @try {
    mark();
  } @catch (NSException *exception) {
    _caughtExceptionReason = [exception.reason ?: exception.name copy];
  }
}

- (void)_postWindowNeedsUpdateConstraints {
  [self catchExceptionOfMark:^{
    [super _postWindowNeedsUpdateConstraints];
  }];
}

- (void)_postWindowNeedsLayout {
  [self catchExceptionOfMark:^{
    [super _postWindowNeedsLayout];
  }];
}

- (void)_postWindowNeedsDisplay {
  [self catchExceptionOfMark:^{
    [super _postWindowNeedsDisplay];
  }];
}

@end
