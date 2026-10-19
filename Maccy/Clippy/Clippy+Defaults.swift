import Defaults

nonisolated extension Defaults.Keys {
  // Top-right corner of the Panel as [x, y] in AppKit screen coordinates. nil = never positioned.
  static let panelTopRight = Key<[Double]?>("panelTopRight")
  static let panelVisible = Key<Bool>("panelVisible", default: true)
  static let panelCollapsed = Key<Bool>("panelCollapsed", default: false)
  static let panelFontScale = Key<Double>("panelFontScale", default: 1.0)
  static let panelIconScale = Key<Double>("panelIconScale", default: 1.0)
}
