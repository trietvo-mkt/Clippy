import AppKit
import Defaults

// Clippy-specific rules. Maccy code reads these instead of hard-coding Clippy behavior.
enum ClippyRules {
  // Sparkle stays off: Clippy updates by merging upstream and rebuilding.
  static let usesSparkle = false

  // Every Copy makes a new Clip, even with duplicate content.
  static let keepsDuplicates = true

  // Plain text only, regardless of Settings.
  static let enabledTypes: Set<NSPasteboard.PasteboardType> = [.string]

  static let maxHistoryLimit = 50

  // Clippy stores plain text only and the Panel sorts by last Copy.
  static let showsStorageTypeAndSort = false

  static let panelScaleRange: ClosedRange<Double> = 0.8...2.0
  static let panelScaleStep = 0.1

  static var historyLimit: Int { min(max(Defaults[.size], 1), maxHistoryLimit) }

  // A Copy that has a file URL (for example a Finder copy) makes no Clip.
  static func shouldIgnore(types: Set<NSPasteboard.PasteboardType>) -> Bool { types.contains(.fileURL) }

  // Select writes the .fromMaccy marker and must not make a Clip.
  static func isSelect(_ pasteboard: NSPasteboard) -> Bool {
    pasteboard.pasteboardItems?.contains(where: { $0.types.contains(.fromMaccy) }) == true
  }
}
