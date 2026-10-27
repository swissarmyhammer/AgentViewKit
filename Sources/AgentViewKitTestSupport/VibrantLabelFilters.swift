import CoreImage
import QuartzCore

/// The vibrancy of the labels in a layer tree, read from PRIVATE Core
/// Animation state, for the composited image of ``ViewSnapshot`` (path C).
///
/// This type is the only code in the kit that reads or changes the private
/// vibrancy filter of Core Animation. Neither AppKit nor SwiftUI has a public
/// reader of it. SwiftUI draws a vibrant label, such as the text of a sidebar
/// `List` row, of a grouped `Form` row in an inspector, or of a `.glass`
/// button, as a white mask in a layer whose `filters` hold one `CAFilter` of
/// the type `vibrantColorMatrix`. Its `inputColorMatrix` is an
/// `NSValue` of a `CAColorMatrix`: twenty `Float` values, one row of four
/// weights and a bias for each of red, green, blue and alpha.
///
/// The values below were measured on macOS 26 (^zbcys18). A label matrix
/// keeps each color channel, adds one bias to each (+0.3 in dark, -0.4 in
/// light), and keeps the alpha. A window on the screen shows such a label in
/// the primary label color: an XCUITest screenshot of the demo Gallery showed
/// the sidebar row text at 255 on 46 in dark and at 0 on 237 in light.
/// `CARenderer` applies the same filter to the pixels behind the layer, so
/// that the label shows mid gray (114 on 37 in dark, 140 on 242 in light).
/// ``withLabelsPainted(in:_:)`` therefore paints the mask of each label in
/// white (a positive bias) or black (a negative bias) for the render, and
/// puts the filter back.
///
/// When Core Animation changes this state, the composited tests of the dark
/// look fail (`CompositedSnapshotTests`), and this type is the one to update.
@MainActor enum VibrantLabelFilters {
  /// The type of the private vibrancy filter.
  static let filterType = "vibrantColorMatrix"

  /// The key of the type of a `CAFilter`.
  static let typeKey = "type"

  /// The key of the color matrix of a vibrancy filter.
  static let matrixKey = "inputColorMatrix"

  /// The name of the Core Image filter that paints a label mask.
  static let paintFilterName = "CIColorMatrix"

  /// Runs `body` while each label of the layer tree under `root` shows its
  /// mask in the primary label color, and then puts the vibrancy filter of
  /// each label back.
  ///
  /// - Parameters:
  ///   - root: The root of the layer tree.
  ///   - body: The work to run, such as a render of `root`.
  static func withLabelsPainted(in root: CALayer, _ body: () -> Void) {
    let labels = labelFilters(in: root)
    swapFilters(of: labels, painted: true)
    defer { swapFilters(of: labels, painted: false) }
    body()
  }

  /// Each layer under `root`, `root` included, with its filters and the
  /// filters that paint its labels, for each layer that has a label filter.
  ///
  /// - Parameter root: The root of the layer tree.
  /// - Returns: The layers, in depth first order.
  private static func labelFilters(in root: CALayer) -> [LabelLayer] {
    let own = LabelLayer(root).map { [$0] } ?? []
    return own + (root.sublayers ?? []).flatMap(labelFilters(in:))
  }

  /// Sets the filters of each of `labels`, without an animation.
  ///
  /// - Parameters:
  ///   - labels: The layers to change.
  ///   - painted: `true` for the filters that paint the labels, `false` for
  ///     the filters of the layers.
  private static func swapFilters(of labels: [LabelLayer], painted: Bool) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    for label in labels {
      label.layer.filters = painted ? label.paintedFilters : label.filters
    }
    CATransaction.commit()
  }

  /// The paint of a label matrix: the filter that shows the mask of a label
  /// in white or in black, with its alpha.
  ///
  /// - Parameter filter: A filter of a layer.
  /// - Returns: The paint, or `nil` when `filter` is not a label filter.
  fileprivate static func paint(for filter: Any) -> CIFilter? {
    guard let matrix = VibrancyMatrix(filter: filter), let bias = matrix.labelBias,
      let paint = CIFilter(name: paintFilterName)
    else { return nil }
    let level: CGFloat = bias > 0 ? 1 : 0
    let none = CIVector(x: 0, y: 0, z: 0, w: 0)
    paint.setValue(none, forKey: "inputRVector")
    paint.setValue(none, forKey: "inputGVector")
    paint.setValue(none, forKey: "inputBVector")
    paint.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
    paint.setValue(CIVector(x: level, y: level, z: level, w: 0), forKey: "inputBiasVector")
    return paint
  }
}

/// A layer with a label filter, with its filters and the filters that paint
/// its label.
@MainActor private struct LabelLayer {
  /// The layer.
  let layer: CALayer

  /// The filters of the layer.
  let filters: [Any]

  /// The filters of the layer, each label filter replaced by its paint.
  let paintedFilters: [Any]

  /// Reads the filters of `layer`.
  ///
  /// - Parameter layer: A layer.
  /// - Returns: `nil` when no filter of `layer` is a label filter.
  init?(_ layer: CALayer) {
    let filters = layer.filters ?? []
    let paints = filters.map(VibrantLabelFilters.paint(for:))
    guard paints.contains(where: { $0 != nil }) else { return nil }
    self.layer = layer
    self.filters = filters
    self.paintedFilters = zip(filters, paints).map { filter, paint in paint ?? filter }
  }
}

/// The color matrix of a vibrancy filter.
struct VibrancyMatrix {
  /// A channel of a color, in the order of the rows of the matrix and of
  /// the weights in a row.
  enum Channel: Int, CaseIterable {
    /// Red.
    case red
    /// Green.
    case green
    /// Blue.
    case blue
    /// Alpha.
    case alpha
  }

  /// The values of one row: a weight for each channel, then a bias.
  static let rowLength = Channel.allCases.count + 1

  /// The number of values of a matrix: one row for each channel.
  static let valueCount = rowLength * Channel.allCases.count

  /// The values, row after row.
  let values: [Float]

  /// Holds `values`.
  ///
  /// - Parameter values: The values, row after row.
  /// - Returns: `nil` when `values` does not hold one value for each place.
  init?(values: [Float]) {
    guard values.count == Self.valueCount else { return nil }
    self.values = values
  }

  /// Reads the matrix of a vibrancy filter.
  ///
  /// - Parameter filter: A filter of a layer.
  /// - Returns: `nil` when `filter` is not a vibrancy filter.
  init?(filter: Any) {
    guard let object = filter as? NSObject,
      object.responds(to: NSSelectorFromString(VibrantLabelFilters.typeKey)),
      object.value(forKey: VibrantLabelFilters.typeKey) as? String == VibrantLabelFilters.filterType,
      let value = object.value(forKey: VibrantLabelFilters.matrixKey) as? NSValue
    else { return nil }
    var values = [Float](repeating: 0, count: Self.valueCount)
    values.withUnsafeMutableBytes { buffer in
      if let address = buffer.baseAddress { value.getValue(address, size: buffer.count) }
    }
    self.init(values: values)
  }

  /// The values of the row of `channel`: a weight for each channel, then a
  /// bias.
  ///
  /// - Parameter channel: The channel of the row.
  /// - Returns: The row.
  func row(_ channel: Channel) -> ArraySlice<Float> {
    let start = channel.rawValue * Self.rowLength
    return values[start..<start + Self.rowLength]
  }

  /// The bias that the matrix adds to each color channel, when the matrix is
  /// a label matrix: it keeps each channel, adds one bias to red, green and
  /// blue, and keeps the alpha. `nil` for another matrix, such as the matrix
  /// of a glass background.
  var labelBias: Float? {
    let biases = Channel.allCases.map { row($0).last ?? 0 }
    let keepsEachChannel = Channel.allCases.allSatisfy { channel in
      Array(row(channel).dropLast()) == Channel.allCases.map { $0 == channel ? 1 : 0 }
    }
    let colorBiases = Set(biases.dropLast())
    guard keepsEachChannel, colorBiases.count == 1, biases.last == 0 else { return nil }
    return colorBiases.first
  }
}
