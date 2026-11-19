import EditorStyle
import EditorTheme
import SwiftUI

/// The environment value that carries the unavailable message of a thread.
extension EnvironmentValues {
  /// The message that the nearest ``AgentThreadView`` shows in place of its
  /// transcript, or `nil`. Set it with ``SwiftUI/View/threadUnavailable(_:)``.
  @Entry var threadUnavailable: String? = nil
}

/// The unavailable state of the thread view.
extension View {
  /// Shows a message of the host in place of the transcript of the thread
  /// views in this view (TestudoApp D208 (i)), such as "The owner stopped
  /// sharing this session.".
  ///
  /// The modifier sets an environment value that ``AgentThreadView`` reads.
  /// Thus it chains with the other modifiers of the thread, such as
  /// ``SwiftUI/View/threadHeader(_:)``, ``SwiftUI/View/sideCards(_:)`` and
  /// ``SwiftUI/View/transcriptSearchHits(_:)``, in each order. Apply it on
  /// the thread view: each thread view in this view shows the message. It
  /// works on each thread, and the host gives the text and its strings.
  ///
  /// The message shows in the center of the thread, in content with no
  /// glass (D110). VoiceOver reads it as a static text with the identifier
  /// ``AgentThreadLayout/unavailableIdentifier``. The header of
  /// ``SwiftUI/View/threadHeader(_:)``, the banners and the floating
  /// controls stay. The scroll-to-bottom pill does not show, because no list
  /// shows.
  ///
  /// While the message shows, the verbs that read the text of the session
  /// are not available, with the reason "The session is not available.":
  /// Copy Message, Copy Thread, Copy Code Block, Export as Markdown…, Find
  /// Next Hit, Find Previous Hit and Clear Search Hits
  /// (``AgentCommandGroup/readsSessionText``).
  ///
  /// ```swift
  /// AgentThreadView(session: shared) { EmptyView() }
  ///   .threadUnavailable(isStopped ? stoppedText : nil)
  /// ```
  ///
  /// - Parameter message: The message, or `nil` to show the transcript.
  /// - Returns: A view whose thread views show the message.
  public func threadUnavailable(_ message: String?) -> some View {
    environment(\.threadUnavailable, message)
  }
}

/// The place of the transcript in a thread view: the transcript, or the
/// unavailable message of the host in its place
/// (``SwiftUI/View/threadUnavailable(_:)``).
struct ThreadTranscriptSlot<Transcript: View, Unavailable: View>: View {
  /// The message of the host, or `nil` to show the transcript.
  let message: String?

  /// The transcript.
  let transcript: Transcript

  /// Makes the view of a message.
  let unavailable: (String) -> Unavailable

  /// Makes a slot with a custom view of the message.
  ///
  /// - Parameters:
  ///   - message: The message of the host, or `nil` to show the transcript.
  ///   - transcript: The builder of the transcript.
  ///   - unavailable: Makes the view of a message.
  init(
    message: String?, @ViewBuilder transcript: () -> Transcript,
    @ViewBuilder unavailable: @escaping (String) -> Unavailable
  ) {
    self.message = message
    self.transcript = transcript()
    self.unavailable = unavailable
  }

  /// The view of the message when the host gave one, else the transcript.
  var body: some View {
    if let message {
      unavailable(message)
    } else {
      transcript
    }
  }
}

extension ThreadTranscriptSlot where Unavailable == ThreadUnavailableView {
  /// Makes a slot that shows a message in a ``ThreadUnavailableView``.
  ///
  /// - Parameters:
  ///   - message: The message of the host, or `nil` to show the transcript.
  ///   - transcript: The builder of the transcript.
  init(message: String?, @ViewBuilder transcript: () -> Transcript) {
    self.init(message: message, transcript: transcript) { ThreadUnavailableView(message: $0) }
  }
}

/// The unavailable message of the host, in the center of a thread.
///
/// The message is content with no glass (D110), in the UI font and the
/// secondary color of the theme. It is one static text with the identifier
/// ``AgentThreadLayout/unavailableIdentifier``. The view fills the place of
/// the transcript, and pads the text with the large spacing of the style.
struct ThreadUnavailableView: View {
  /// The message of the host.
  let message: String

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.themeSecondary) private var themeSecondary

  var body: some View {
    Text(message)
      .font(editorTheme.uiFont)
      .foregroundStyle(themeSecondary)
      .multilineTextAlignment(.center)
      .accessibilityIdentifier(AgentThreadLayout.unavailableIdentifier)
      .padding(editorStyle.spacing.l)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
