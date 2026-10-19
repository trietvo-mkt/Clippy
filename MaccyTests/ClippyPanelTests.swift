import XCTest
@testable import Maccy

@MainActor
class ClippyPanelTests: XCTestCase {
  let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
  let size = ClippyPanelLayout.expandedSize

  func testSavedPointOnScreenIsKept() {
    let saved = NSPoint(x: 800, y: 600)
    let result = ClippyPanelLayout.resolvedTopRight(saved: saved, screens: [screen], mainScreen: screen, size: size)
    XCTAssertEqual(result, saved)
  }

  func testSavedPointOffAllScreensFallsBackToCenterOfMain() {
    // The second screen was unplugged, so the saved corner is off every remaining screen.
    let saved = NSPoint(x: 3000, y: 500)
    let result = ClippyPanelLayout.resolvedTopRight(saved: saved, screens: [screen], mainScreen: screen, size: size)
    XCTAssertEqual(result, NSPoint(x: 720 + 150, y: 450 + 170))
  }

  func testNilSavedCentersOnMain() {
    let result = ClippyPanelLayout.resolvedTopRight(saved: nil, screens: [screen], mainScreen: screen, size: size)
    let frame = ClippyPanelLayout.frame(topRight: result, size: size)
    XCTAssertEqual(frame.midX, screen.midX)
    XCTAssertEqual(frame.midY, screen.midY)
  }

  func testExpandedAndCollapsedFramesShareTopRight() {
    let topRight = NSPoint(x: 1000, y: 700)
    let expanded = ClippyPanelLayout.frame(topRight: topRight, size: size)
    let collapsed = ClippyPanelLayout.frame(topRight: topRight, size: ClippyPanelLayout.collapsedSize(iconScale: 1))
    XCTAssertEqual(expanded.maxX, collapsed.maxX)
    XCTAssertEqual(expanded.maxY, collapsed.maxY)
    XCTAssertEqual(expanded.maxX, topRight.x)
    XCTAssertEqual(expanded.maxY, topRight.y)
  }

  func testCollapsedSizeScalesWithIconScale() {
    XCTAssertEqual(ClippyPanelLayout.collapsedSize(iconScale: 1.5), NSSize(width: 66, height: 66))
  }
}
