import AppKit
import Metal
import QuartzCore

/// Renders the layer tree of a view in a window with `CARenderer`, the
/// renderer of Core Animation, in the test process: the composited image of
/// ``ViewSnapshot`` (path C, ^zbcys18).
///
/// The cache of a window (path A) draws each layer by itself, with no layer
/// filter and no backdrop. So it shows no Liquid Glass, no scroll edge effect,
/// no glyph of a symbol-only glass button, and a vibrant label as its bare
/// mask. `CARenderer` draws the same layer tree with the filters and the
/// backdrops, as the render server of the system draws a window on the
/// screen. Measured on macOS 26: a glass changes the color under it, the rows
/// of a grouped inspector form are dark in dark mode, the mic and Send buttons
/// of the composer show, and two renders of one window give the same pixels.
///
/// For the render, the layer of the view moves into a container layer that
/// scales it to the pixels of the image and flips it, so that the first row of
/// the image is the top of the view. Each label shows in the primary label
/// color (``VibrantLabelFilters``). The layer and the filters go back before
/// the function returns, so the window is as it was.
@MainActor enum LayerTreeRenderer {
  /// The pixel format of the render target: four bytes for each pixel, in
  /// the order blue, green, red, alpha.
  static let pixelFormat = MTLPixelFormat.bgra8Unorm

  /// The distance from the blue byte of a pixel to its red byte, in the
  /// order of ``pixelFormat``. ``RenderedPixels`` holds red first.
  static let blueToRedDistance = 2

  /// The command queue of the renders, or `nil` when the computer has no
  /// Metal device.
  static let commandQueue = MTLCreateSystemDefaultDevice()?.makeCommandQueue()

  /// Renders the layer tree of `view` at `scale` pixels for each point.
  ///
  /// - Parameters:
  ///   - view: A layer-backed view in a window.
  ///   - scale: The number of pixels for each point.
  /// - Returns: The pixels, in sRGB, or `nil` when the view has no layer or
  ///   no area, or the computer has no Metal device.
  static func pixels(of view: NSView, scale: CGFloat) -> RenderedPixels? {
    guard let layer = view.layer, let queue = commandQueue,
      let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let texture = makeTexture(size: view.bounds.size, scale: scale, device: queue.device)
    else { return nil }
    var isRendered = false
    VibrantLabelFilters.withLabelsPainted(in: layer) {
      withContainer(of: layer, scale: scale) { container in
        isRendered = render(container, into: texture, colorSpace: colorSpace, queue: queue)
      }
    }
    return isRendered ? pixels(of: texture, scale: scale) : nil
  }

  /// An empty render target for a view of `size` points.
  ///
  /// - Parameters:
  ///   - size: The size of the view, in points.
  ///   - scale: The number of pixels for each point.
  ///   - device: The Metal device.
  /// - Returns: The texture, or `nil` when it has no pixel or Metal cannot
  ///   make it.
  private static func makeTexture(size: CGSize, scale: CGFloat, device: MTLDevice) -> MTLTexture? {
    let width = Int((size.width * scale).rounded())
    let height = Int((size.height * scale).rounded())
    guard width > 0, height > 0 else { return nil }
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: pixelFormat, width: width, height: height, mipmapped: false)
    descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
    descriptor.storageMode = .shared
    return device.makeTexture(descriptor: descriptor)
  }

  /// Runs `body` while `layer` stands in a container layer that scales it by
  /// `scale` and flips it, and then puts `layer` back in its superlayer, at
  /// its place.
  ///
  /// - Parameters:
  ///   - layer: The layer of the view.
  ///   - scale: The number of pixels for each point.
  ///   - body: The work to run with the container, such as a render.
  private static func withContainer(of layer: CALayer, scale: CGFloat, _ body: (CALayer) -> Void) {
    let superlayer = layer.superlayer
    let index = superlayer?.sublayers?.firstIndex(of: layer)
    let position = layer.position
    let container = CALayer()
    container.anchorPoint = .zero
    container.bounds = CGRect(origin: .zero, size: layer.bounds.size.applying(CGAffineTransform(scaleX: scale, y: scale)))
    container.isGeometryFlipped = true
    container.sublayerTransform = CATransform3DMakeScale(scale, scale, 1)
    withoutActions {
      container.addSublayer(layer)
      layer.position = CGPoint(
        x: layer.bounds.width * layer.anchorPoint.x, y: layer.bounds.height * layer.anchorPoint.y)
    }
    defer {
      withoutActions {
        layer.removeFromSuperlayer()
        if let superlayer, let index { superlayer.insertSublayer(layer, at: UInt32(index)) }
        layer.position = position
      }
    }
    body(container)
  }

  /// Runs `changes` in a transaction with no animation.
  ///
  /// - Parameter changes: The layer changes.
  private static func withoutActions(_ changes: () -> Void) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    changes()
    CATransaction.commit()
  }

  /// Renders `layer` into `texture`, and waits until the GPU has written
  /// each pixel.
  ///
  /// - Parameters:
  ///   - layer: The root layer of the render.
  ///   - texture: The render target.
  ///   - colorSpace: The color space of the pixels.
  ///   - queue: The command queue of the render.
  /// - Returns: `true` when the GPU has written the pixels, and `false` when
  ///   Metal gave no command buffer to wait on.
  private static func render(
    _ layer: CALayer, into texture: MTLTexture, colorSpace: CGColorSpace, queue: MTLCommandQueue
  ) -> Bool {
    let renderer = CARenderer(
      mtlTexture: texture,
      options: [kCARendererColorSpace: colorSpace, kCARendererMetalCommandQueue: queue])
    renderer.layer = layer
    renderer.bounds = layer.bounds
    CATransaction.flush()
    renderer.beginFrame(atTime: CACurrentMediaTime(), timeStamp: nil)
    renderer.addUpdate(renderer.bounds)
    renderer.render()
    renderer.endFrame()
    return waitForCommands(of: queue)
  }

  /// Waits until the GPU has run each command that `queue` holds: an empty
  /// command buffer runs after the commands of the render.
  ///
  /// - Parameter queue: The command queue of the render.
  /// - Returns: `true` after the wait, and `false` when Metal gave no command
  ///   buffer to wait on.
  private static func waitForCommands(of queue: MTLCommandQueue) -> Bool {
    guard let commands = queue.makeCommandBuffer() else { return false }
    commands.commit()
    commands.waitUntilCompleted()
    return true
  }

  /// The pixels of `texture`, red first.
  ///
  /// - Parameters:
  ///   - texture: The render target, after the render.
  ///   - scale: The number of pixels for each point.
  /// - Returns: The pixels.
  private static func pixels(of texture: MTLTexture, scale: CGFloat) -> RenderedPixels {
    let bytesPerRow = texture.width * RenderedPixels.bytesPerPixel
    var bytes = [UInt8](repeating: 0, count: bytesPerRow * texture.height)
    texture.getBytes(
      &bytes, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
    for offset in stride(from: 0, to: bytes.count, by: RenderedPixels.bytesPerPixel) {
      bytes.swapAt(offset, offset + blueToRedDistance)
    }
    return RenderedPixels(bytes: bytes, width: texture.width, height: texture.height, scale: scale)
  }
}
