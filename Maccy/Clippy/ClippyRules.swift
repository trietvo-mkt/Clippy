import Foundation

// Clippy-specific rules. Maccy code reads these instead of hard-coding Clippy behavior.
enum ClippyRules {
  // Sparkle stays off: Clippy updates by merging upstream and rebuilding.
  static let usesSparkle = false
}
