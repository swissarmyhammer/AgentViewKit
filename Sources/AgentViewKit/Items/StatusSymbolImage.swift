import EditorStyle
import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The symbol of a state, such as a status or a priority, in a color of the
/// EditorKit theme.
///
/// The view shows the symbol with the hierarchical rendering mode of the
/// status views and the symbol weight of the shared style. Each caller keeps its
/// own map from its state to the symbol name and to the color.
/// ``ToolStatusImage``, the plan entry of ``TaskListView``, `StatusBar`, the
/// header of ``CompactionEntryView``, the card of ``ErrorView``, the banner of
/// ``SessionNoticeBanner``, the rows of ``ActivityTimeline`` and
/// ``StatusCaptionLabel`` draw their
/// symbols with this view, so a change of the rendering mode or of the weight
/// reaches each of them. A caller adds its own symbol effects to
/// the view.
struct StatusSymbolImage: View {
  /// The SF Symbol name. Read it from ``SharedSymbol``, from `ItemStatus` or
  /// `ItemPriority` of EditorStyle, or from the symbol map of the caller.
  let name: String

  /// The color of the symbol: a color of the EditorKit theme, or
  /// `Color.secondary` for a row with no state color.
  let color: Color

  @Environment(\.editorStyle) private var editorStyle

  var body: some View {
    Image(systemName: name)
      .symbolRenderingMode(.hierarchical)
      .fontWeight(editorStyle.symbolWeight)
      .foregroundStyle(color)
  }
}

// MARK: - Previews

/// The sheets of the states that the callers of ``StatusSymbolImage`` map to
/// a symbol and a color: the status and the priority of a plan entry
/// (``TaskListView``), and the severity of a notice
/// (``SessionNoticeBanner``). Each state shows its symbol in its color of the
/// EditorKit theme.
private struct StatusSymbolSheets: View {
  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    VStack(alignment: .leading, spacing: editorStyle.spacing.l) {
      PreviewSymbolSheet(
        title: "Plan entry status", values: PreviewFixtures.planEntryStatuses, label: TaskListView.statusLabel
      ) { status in
        StatusSymbolImage(name: TaskListView.statusSymbol(status), color: editorTheme.statusColor(for: status))
      }
      PreviewSymbolSheet(
        title: "Plan entry priority", values: PreviewFixtures.planEntryPriorities, label: TaskListView.priorityLabel
      ) { priority in
        StatusSymbolImage(name: TaskListView.prioritySymbol(priority), color: editorTheme.tint(for: priority))
      }
      PreviewSymbolSheet(
        title: "Notice severity", values: PreviewFixtures.noticeSeverities, label: NoticeBanner.severityLabel
      ) { severity in
        StatusSymbolImage(name: NoticeBanner.symbolName(for: severity), color: editorTheme.tint(for: severity))
      }
    }
    .padding()
  }
}

#Preview("Each status, priority and severity") {
  StatusSymbolSheets()
}
