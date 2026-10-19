// PROTOTYPE (throwaway): three Panel variants, switchable from the debug bar. Answers issue trietvo-mkt/Clippy#5. Never merge.
import AppKit
import KeyboardShortcuts
import SwiftUI

extension KeyboardShortcuts.Name {
  static let panelPrototypeToggle = Self(
    "panelPrototypeToggle",
    initial: Shortcut(.v, modifiers: [.control, .option, .command])
  )
}

enum PanelPrototypeVariant: Int, CaseIterable {
  case rightStrip, bottomShelf, floatingCompact

  var letter: String { ["A", "B", "C"][rawValue] }
  var title: String { ["Right strip", "Bottom shelf", "Floating compact"][rawValue] }
  var next: Self { Self(rawValue: (rawValue + 1) % 3)! }
  var prev: Self { Self(rawValue: (rawValue + 2) % 3)! }
}

// Window that never activates the app. Key status is runtime-toggleable.
final class PanelPrototypeWindow: NSPanel {
  var allowKey = false
  override var canBecomeKey: Bool { allowKey }
  override var canBecomeMain: Bool { allowKey }

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

final class PanelPrototypeHostingView<Content: View>: NSHostingView<Content> {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

enum PanelPrototypeGlass: Int, CaseIterable {
  case hud, light, liquid

  var label: String { ["hud", "light", "liquid (26+)"][rawValue] }
  var next: Self { Self(rawValue: (rawValue + 1) % 3)! }
}

final class PanelPrototypeModel: ObservableObject {
  @Published var variant = PanelPrototypeVariant.floatingCompact
  @Published var glass = PanelPrototypeGlass.hud
  @Published var collapsed = false
  @Published var isKey = false
  @Published var frontmost = ""
  @Published var levelName = "statusBar"
  @Published var canBecomeKey = false
  @Published var currentText: String?
  @Published var log = "(no action yet)"
}

final class PanelPrototype {
  static let shared = PanelPrototype()

  let model = PanelPrototypeModel()
  private var window: PanelPrototypeWindow!
  private var statusItem: NSStatusItem!
  private var timer: Timer?
  private var lastChangeCount = -1
  private var lastSelectedText: String?
  private let levels: [(String, NSWindow.Level)] = [
    ("statusBar", .statusBar), ("popUpMenu", .popUpMenu), ("screenSaver", .screenSaver)
  ]
  private var levelIndex = 0
  private let originKey = "panelPrototypeOrigin"

  func start() {
    window = PanelPrototypeWindow(contentRect: frame(for: model.variant))
    NotificationCenter.default.addObserver(
      forName: NSWindow.didMoveNotification, object: window, queue: .main
    ) { [weak self] _ in self?.saveOrigin() }
    window.contentView = PanelPrototypeHostingView(rootView: PanelPrototypeRootView(model: model, proto: self))
    applyFrame()
    window.orderFrontRegardless()

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.button?.image = NSImage(systemSymbolName: "rectangle.stack", accessibilityDescription: "Panel prototype")
    statusItem.button?.target = self
    statusItem.button?.action = #selector(toggle)
    KeyboardShortcuts.onKeyUp(for: .panelPrototypeToggle) { [weak self] in self?.toggle() }

    timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in self?.tick() }
    tick()
  }

  @objc func toggle() {
    if window.isVisible { window.orderOut(nil) } else { window.orderFrontRegardless() }
  }

  private func tick() {
    model.isKey = window.isKeyWindow
    model.frontmost = NSWorkspace.shared.frontmostApplication?.localizedName ?? "-"
    model.levelName = levels[levelIndex].0
    model.canBecomeKey = window.allowKey
    let pb = NSPasteboard.general
    if pb.changeCount != lastChangeCount {
      if lastChangeCount != -1, let text = pb.string(forType: .string), text != lastSelectedText {
        model.log = "External copy at \(timeString()) — changeCount \(pb.changeCount)"
      }
      lastChangeCount = pb.changeCount
      model.currentText = pb.string(forType: .string)
    }
  }

  private func timeString() -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    return f.string(from: Date())
  }

  func select(index: Int, text: String) {
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setString(text, forType: .string)
    // Marker so Maccy's watcher ignores this write and History stays unchanged.
    pb.setString("", forType: .transient)
    lastSelectedText = text
    lastChangeCount = pb.changeCount
    model.currentText = text
    model.log = "Select #\(index) at \(timeString()) — pasteboard changeCount \(pb.changeCount) — History unchanged (transient marker)"
  }

  func setVariant(_ v: PanelPrototypeVariant) {
    model.variant = v
    model.collapsed = false
    applyFrame()
  }

  // Save the origin only for the expanded variant C.
  private func saveOrigin() {
    guard model.variant == .floatingCompact, !model.collapsed, window.frame.width == 300 else { return }
    let o = window.frame.origin
    UserDefaults.standard.set([o.x, o.y], forKey: originKey)
  }

  private func savedOrigin() -> NSPoint? {
    guard let a = UserDefaults.standard.array(forKey: originKey) as? [Double], a.count == 2 else { return nil }
    let o = NSPoint(x: a[0], y: a[1])
    return NSScreen.screens.contains { $0.visibleFrame.contains(o) } ? o : nil
  }

  func cycleGlass() { model.glass = model.glass.next }

  func setCollapsed(_ c: Bool) {
    model.collapsed = c
    applyFrame()
  }

  func cycleLevel() {
    levelIndex = (levelIndex + 1) % levels.count
    window.level = levels[levelIndex].1
    model.levelName = levels[levelIndex].0
  }

  func toggleCanBecomeKey() {
    window.allowKey.toggle()
    model.canBecomeKey = window.allowKey
  }

  private func applyFrame() {
    var f = frame(for: model.variant)
    if model.variant == .floatingCompact, model.collapsed {
      f.size = NSSize(width: 44, height: 44)
      f.origin = NSPoint(x: window.frame.maxX - 44, y: window.frame.maxY - 44)
      if window.frame.size == f.size { return }
    } else if model.variant == .floatingCompact, window.frame.size.width == 44 {
      f.origin = NSPoint(x: window.frame.maxX - f.width, y: window.frame.maxY - f.height)
    }
    window.setFrame(f, display: true)
  }

  private func frame(for v: PanelPrototypeVariant) -> NSRect {
    let vf = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
    switch v {
    case .rightStrip:
      return NSRect(x: vf.maxX - 260, y: vf.minY, width: 260, height: vf.height)
    case .bottomShelf:
      return NSRect(x: vf.minX + 20, y: vf.minY + 10, width: vf.width - 40, height: 110)
    case .floatingCompact:
      let o = savedOrigin() ?? NSPoint(x: vf.midX - 150, y: vf.midY - 170)
      return NSRect(origin: o, size: NSSize(width: 300, height: 340))
    }
  }
}
