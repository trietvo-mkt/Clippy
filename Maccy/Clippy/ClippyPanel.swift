import AppKit
import Defaults
import Observation
import SwiftUI

// The Panel window. It never becomes key or main, so clicking it does not steal focus from the
// app the user is typing in.
final class ClippyPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }

  init(contentRect: NSRect) {
    super.init(
      contentRect: contentRect,
      styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    isFloatingPanel = true
    hidesOnDeactivate = false
    level = .statusBar
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    isMovableByWindowBackground = true
  }
}

// Without acceptsFirstMouse, the first click on a non-key window never reaches SwiftUI.
final class ClippyPanelHostingView<Content: View>: NSHostingView<Content> {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// Pure geometry for the Panel, kept free of AppKit windows so it can be unit tested.
// Coordinates are AppKit screen coordinates (y points up).
enum ClippyPanelLayout {
  static let expandedSize = NSSize(width: 300, height: 340)
  static let collapsedBaseSize: CGFloat = 44

  static func collapsedSize(iconScale: Double) -> NSSize {
    let side = collapsedBaseSize * iconScale
    return NSSize(width: side, height: side)
  }

  // Rect of the given size whose top-right corner is topRight.
  static func frame(topRight: NSPoint, size: NSSize) -> NSRect {
    NSRect(x: topRight.x - size.width, y: topRight.y - size.height, width: size.width, height: size.height)
  }

  // Use the saved corner if the Panel would still touch a screen. Otherwise center it on the main screen.
  static func resolvedTopRight(saved: NSPoint?, screens: [NSRect], mainScreen: NSRect, size: NSSize) -> NSPoint {
    if let saved, screens.contains(where: { frame(topRight: saved, size: size).intersects($0) }) {
      return saved
    }
    return NSPoint(x: mainScreen.midX + size.width / 2, y: mainScreen.midY + size.height / 2)
  }
}

// Drives the SwiftUI root view. The controller flips collapsed; the view reads it.
@Observable
final class ClippyPanelModel {
  var collapsed = false
}

final class ClippyPanelController {
  static let shared = ClippyPanelController()

  let model = ClippyPanelModel()

  private static let expandedCornerRadius: CGFloat = 12
  private static let collapsedCornerRadius: CGFloat = 10

  private var panel: ClippyPanel?
  private var background: NSVisualEffectView?
  private var observers: [NSObjectProtocol] = []
  private var iconScaleTask: Task<Void, Never>?

  private var size: NSSize {
    model.collapsed
      ? ClippyPanelLayout.collapsedSize(iconScale: Defaults[.panelIconScale])
      : ClippyPanelLayout.expandedSize
  }

  func start() {
    guard panel == nil else { return }

    model.collapsed = Defaults[.panelCollapsed]
    let panel = ClippyPanel(contentRect: NSRect(origin: .zero, size: size))

    // Frosted glass. state = .active is required because Clippy is never the active app.
    let background = NSVisualEffectView()
    background.material = .hudWindow
    background.blendingMode = .behindWindow
    background.state = .active
    background.wantsLayer = true
    background.layer?.masksToBounds = true

    let hosting = ClippyPanelHostingView(rootView: ClippyPanelView(model: model))
    hosting.sizingOptions = []
    hosting.frame = background.bounds
    hosting.autoresizingMask = [.width, .height]
    background.addSubview(hosting)

    panel.contentView = background
    self.panel = panel
    self.background = background
    updateCornerRadius()

    let saved = Defaults[.panelTopRight].flatMap { $0.count == 2 ? NSPoint(x: $0[0], y: $0[1]) : nil }
    panel.setFrame(ClippyPanelLayout.frame(topRight: resolveTopRight(saved: saved), size: size), display: true)

    observe()

    if Defaults[.panelVisible] {
      panel.orderFrontRegardless()
    }
  }

  func show() {
    panel?.orderFrontRegardless()
    Defaults[.panelVisible] = true
  }

  func hide() {
    panel?.orderOut(nil)
    Defaults[.panelVisible] = false
  }

  func toggle() {
    if panel?.isVisible == true { hide() } else { show() }
  }

  // Resizes the Panel and keeps its top-right corner where it was.
  func setCollapsed(_ collapsed: Bool) {
    model.collapsed = collapsed
    Defaults[.panelCollapsed] = collapsed
    updateCornerRadius()
    applySizeKeepingTopRight()
  }

  private func applySizeKeepingTopRight() {
    guard let panel else { return }
    let topRight = NSPoint(x: panel.frame.maxX, y: panel.frame.maxY)
    panel.setFrame(ClippyPanelLayout.frame(topRight: topRight, size: size), display: true)
  }

  private func updateCornerRadius() {
    background?.layer?.cornerRadius = model.collapsed
      ? Self.collapsedCornerRadius
      : Self.expandedCornerRadius
  }

  private func resolveTopRight(saved: NSPoint?) -> NSPoint {
    let screens = NSScreen.screens.map(\.visibleFrame)
    let main = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? .zero
    return ClippyPanelLayout.resolvedTopRight(saved: saved, screens: screens, mainScreen: main, size: size)
  }

  private func observe() {
    let center = NotificationCenter.default

    // Remember where the user dragged the Panel.
    observers.append(center.addObserver(
      forName: NSWindow.didMoveNotification, object: panel, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.saveTopRight() }
    })

    // A screen was removed or resized. Recenter if the Panel is now off every screen.
    observers.append(center.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.recoverIfOffScreen() }
    })

    iconScaleTask = Task { [weak self] in
      for await _ in Defaults.updates(.panelIconScale, initial: false) {
        guard let self, self.model.collapsed else { continue }
        self.applySizeKeepingTopRight()
      }
    }
  }

  private func saveTopRight() {
    guard let panel else { return }
    Defaults[.panelTopRight] = [panel.frame.maxX, panel.frame.maxY]
  }

  private func recoverIfOffScreen() {
    guard let panel else { return }
    let screens = NSScreen.screens.map(\.visibleFrame)
    guard !screens.contains(where: { panel.frame.intersects($0) }) else { return }
    panel.setFrame(ClippyPanelLayout.frame(topRight: resolveTopRight(saved: nil), size: size), display: true)
  }
}
