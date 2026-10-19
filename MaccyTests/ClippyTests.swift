import XCTest
import Defaults
@testable import Maccy

@MainActor
class ClippyTests: XCTestCase {
  let savedSize = Defaults[.size]
  let savedSortBy = Defaults[.sortBy]
  let savedPinOrder = Defaults[.pinOrder]
  let savedPinTo = Defaults[.pinTo]
  let history = History.shared
  let pasteboard = NSPasteboard.general

  override func setUp() {
    super.setUp()
    MainActor.assumeIsolated {
      History.shared.clearAll()
      Clipboard.shared.clearHooks()
      CurrentClip.shared.clear()
    }
    Defaults[.size] = 20
    Defaults[.sortBy] = .firstCopiedAt
    Defaults[.pinOrder] = PinOrder()
    Defaults[.pinTo] = .bottom
  }

  override func tearDown() {
    super.tearDown()
    MainActor.assumeIsolated {
      Clipboard.shared.clearHooks()
      CurrentClip.shared.clear()
    }
    Defaults[.size] = savedSize
    Defaults[.sortBy] = savedSortBy
    Defaults[.pinOrder] = savedPinOrder
    Defaults[.pinTo] = savedPinTo
  }

  // Copy a, b, a: all three are kept, newest first.
  func testDuplicateContentMakesSeparateClips() {
    addABA()

    XCTAssertEqual(history.items.count, 3)
    XCTAssertEqual(history.items.map(\.title), ["a", "b", "a"])
  }

  // Select b: History is unchanged and only b is the current Clip.
  func testSelectDoesNotAddClipAndMarksOnlySelectedAsCurrent() async throws {
    let (firstA, bDecorator, secondA) = addABA()
    Clipboard.shared.onNewCopy { History.shared.add($0) }

    Clipboard.shared.copy(bDecorator.item)
    try await Task.sleep(nanoseconds: 300_000_000)
    Clipboard.shared.checkForChangesInPasteboard()

    XCTAssertEqual(history.items.count, 3)
    XCTAssertEqual(history.items.map(\.title), ["a", "b", "a"])
    XCTAssertTrue(CurrentClip.shared.isCurrent(bDecorator.item))
    XCTAssertFalse(CurrentClip.shared.isCurrent(firstA.item))
    XCTAssertFalse(CurrentClip.shared.isCurrent(secondA.item))
  }

  // Any later write to the pasteboard changes changeCount, so the selected Clip is no longer current.
  func testClipStopsBeingCurrentAfterPasteboardChanges() async throws {
    let (_, bDecorator, _) = addABA()

    Clipboard.shared.copy(bDecorator.item)
    try await Task.sleep(nanoseconds: 300_000_000)
    XCTAssertTrue(CurrentClip.shared.isCurrent(bDecorator.item))

    pasteboard.clearContents()
    pasteboard.setString("something else", forType: .string)

    XCTAssertFalse(CurrentClip.shared.isCurrent(bDecorator.item))
  }

  func testHistoryLimitKeepsPinnedAndDropsOldestUnpinned() {
    Defaults[.size] = 20

    let pinned = history.add(historyItem("pinned"))
    history.togglePin(pinned)

    // Like HistoryTests.testMaxSizeIgnoresPinned: pinned Clips do not count toward the limit,
    // so 21 unpinned Clips (limit + 1) leave exactly 20 unpinned plus the 1 pinned Clip.
    var unpinned: [HistoryItemDecorator] = []
    for index in 1...21 {
      unpinned.append(history.add(historyItem(String(index))))
    }

    XCTAssertEqual(history.unpinnedItems.count, 20)
    XCTAssertEqual(history.items.count, 21)
    XCTAssertTrue(history.items.contains(pinned))
    XCTAssertFalse(history.items.contains(unpinned[0]))
    XCTAssertTrue(history.items.contains(unpinned[1]))
    XCTAssertTrue(history.items.contains(unpinned[20]))
  }

  func testHistoryLimitIsClamped() {
    Defaults[.size] = 0
    XCTAssertEqual(ClippyRules.historyLimit, 1)

    Defaults[.size] = 999
    XCTAssertEqual(ClippyRules.historyLimit, 50)
  }

  func testFileURLCopyIsIgnored() {
    let existing = history.add(historyItem("existing"))
    CurrentClip.shared.set(existing.item, changeCount: pasteboard.changeCount)

    var hookCalls = 0
    Clipboard.shared.onNewCopy { _ in hookCalls += 1 }

    pasteboard.clearContents()
    pasteboard.writeObjects([NSURL(fileURLWithPath: "/tmp/x.txt")])
    pasteboard.addTypes([.string], owner: nil)
    pasteboard.setString("x.txt", forType: .string)
    XCTAssertTrue(pasteboard.types?.contains(.fileURL) == true)

    Clipboard.shared.checkForChangesInPasteboard()

    XCTAssertEqual(hookCalls, 0)
    XCTAssertNil(CurrentClip.shared.item)
  }

  @discardableResult
  private func addABA() -> (HistoryItemDecorator, HistoryItemDecorator, HistoryItemDecorator) {
    let first = history.add(historyItem("a"))
    let second = history.add(historyItem("b"))
    let third = history.add(historyItem("a"))
    return (first, second, third)
  }

  private func historyItem(_ value: String) -> HistoryItem {
    let contents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: value.data(using: .utf8)
      )
    ]
    let item = HistoryItem()
    Storage.shared.context.insert(item)
    item.contents = contents
    item.numberOfCopies = 1
    item.title = item.generateTitle()

    return item
  }
}
