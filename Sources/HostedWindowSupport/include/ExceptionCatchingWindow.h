#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A window that catches the Objective-C exception of a loop of its display
/// cycle, keeps its reason, and ends the loop.
///
/// AppKit throws an `NSGenericException` when a view marks the window as
/// needing another pass more times than the window has views, for example
/// "more Update Constraints in Window passes than there are views in the
/// window". The exception comes from a run loop observer of the display
/// cycle, in a constraint update pass or in a layout pass. Swift cannot
/// catch an Objective-C exception, and the layout code of AppKit stops the
/// process on it. Thus without this window the exception stops the test
/// process, and the other tests do not run. This window catches the
/// exception where AppKit throws it, and then drops each later mark, so that
/// the loop ends. The hosted view harness gives the reason to the test, and
/// the test fails.
@interface ExceptionCatchingWindow : NSWindow

/// `YES` when `NSWindow` has each method that marks a window as needing
/// another pass of its display cycle.
///
/// The window catches the exception of a loop in these methods. The methods
/// are not public, so a release of AppKit can remove them. Then the window
/// catches nothing, and a test expects `YES`.
@property(class, nonatomic, readonly) BOOL appKitHasTheMarkMethods;

/// The reason of the exception of a display cycle loop that the window
/// caught, or `nil` when the window caught no exception.
@property(nonatomic, readonly, copy, nullable) NSString *caughtExceptionReason;

@end

NS_ASSUME_NONNULL_END
