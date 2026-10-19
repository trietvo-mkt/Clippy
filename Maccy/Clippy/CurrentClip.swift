import AppKit
import Observation

// The Clip on the clipboard right now, if Clippy put it there (Copy or Select).
// Tracked by HistoryItem object identity plus NSPasteboard changeCount, not by text,
// so duplicate Clips are told apart. SwiftData persistentModelID is not used because
// it changes from a temporary to a permanent id when the item is saved.
@Observable
final class CurrentClip {
  static let shared = CurrentClip()

  private(set) var item: HistoryItem?
  private(set) var changeCount: Int?

  func set(_ item: HistoryItem, changeCount: Int) {
    self.item = item
    self.changeCount = changeCount
  }

  func clear() {
    item = nil
    changeCount = nil
  }

  // False once anything else has written to the clipboard since the Clip was set.
  func isCurrent(_ item: HistoryItem, pasteboardChangeCount: Int = NSPasteboard.general.changeCount) -> Bool {
    guard let current = self.item, let changeCount else { return false }
    return current === item && changeCount == pasteboardChangeCount
  }
}
