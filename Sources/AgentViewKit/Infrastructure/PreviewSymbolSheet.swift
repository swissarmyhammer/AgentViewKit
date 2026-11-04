import EditorStyle
import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The sheet of the states of an icon view, for the `#Preview` of the view.
///
/// The sheet is a grid with a title and one row for each state: the icon of
/// the state, then the name of the state. No view of the kit sets a font on
/// its icons, so the kit draws each icon at the font of its row. An icon is
/// chrome, so the sheet draws the icons and the names at the UI font of the
/// EditorKit theme (the `ui` font role).
struct PreviewSymbolSheet<Value: Hashable, Icon: View>: View {
  /// The title of the sheet, such as the name of the type of the states.
  let title: String

  /// The states, in the order of the rows.
  let values: [Value]

  /// The function that gives the name of a state.
  let label: (Value) -> String

  /// The function that makes the icon of a state.
  @ViewBuilder let icon: (Value) -> Icon

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    VStack(alignment: .leading, spacing: editorStyle.spacing.s) {
      Text(title)
        .font(editorTheme.font(for: .ui, style: .headline))
      Grid(alignment: .leading, horizontalSpacing: editorStyle.spacing.m, verticalSpacing: editorStyle.spacing.s) {
        ForEach(values, id: \.self) { value in
          GridRow {
            icon(value)
            Text(label(value))
          }
        }
      }
    }
  }
}

// MARK: - Previews

#Preview("The sheet of the status symbols") {
  PreviewSymbolSheet(title: "Status symbol", values: PreviewFixtures.statusSymbolNames, label: \.self) { name in
    DecorativeSymbolImage(name: name)
  }
  .padding()
}

/// The sheets of the states that the kit maps to an EditorKit symbol and a
/// tone: the status and the priority of a plan entry (``TaskListView``), and
/// the severity of a notice (``SessionNoticeBanner``). Each state shows its
/// symbol in its tone of the EditorKit theme.
private struct StatusSymbolSheets: View {
  @Environment(\.editorStyle) private var editorStyle

  var body: some View {
    VStack(alignment: .leading, spacing: editorStyle.spacing.l) {
      PreviewSymbolSheet(
        title: "Plan entry status", values: PreviewFixtures.planEntryStatuses, label: { EditorStatus($0).summary }
      ) { status in
        let token = EditorStatus(status)
        EditorSymbolImage(systemName: token.systemImage, tone: token.tone)
      }
      PreviewSymbolSheet(
        title: "Plan entry priority", values: PreviewFixtures.planEntryPriorities, label: TaskListView.priorityLabel
      ) { priority in
        EditorSymbolImage(systemName: TaskListView.prioritySymbol(priority), tone: .init(priority))
      }
      PreviewSymbolSheet(
        title: "Notice severity", values: PreviewFixtures.noticeSeverities, label: NoticeBanner.severityLabel
      ) { severity in
        EditorSymbolImage(
          systemName: NoticeBanner.symbolName(for: severity), tone: StatusBar.Message.Severity(notice: severity).tone)
      }
    }
    .padding()
  }
}

#Preview("Each status, priority and severity") {
  StatusSymbolSheets()
}
