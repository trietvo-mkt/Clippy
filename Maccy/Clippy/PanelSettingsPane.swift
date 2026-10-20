import SwiftUI
import Defaults
import KeyboardShortcuts
import Settings
import enum Settings.Settings

// Lets `if` sit between Sections inside Settings.Container.
extension Settings.SectionBuilder {
  static func buildExpression(_ section: Settings.Section) -> [Settings.Section] { [section] }

  static func buildBlock(_ parts: [Settings.Section]...) -> [Settings.Section] { parts.flatMap { $0 } }

  static func buildOptional(_ parts: [Settings.Section]?) -> [Settings.Section] { parts ?? [] }

  static func buildEither(first parts: [Settings.Section]) -> [Settings.Section] { parts }

  static func buildEither(second parts: [Settings.Section]) -> [Settings.Section] { parts }
}

struct PanelSettingsPane: View {
  @Default(.panelIconScale) private var iconScale
  @Default(.panelFontScale) private var fontScale
  @Default(.panelSizeScale) private var sizeScale
  @Default(.panelBackgroundOpacity) private var backgroundOpacity

  var body: some View {
    Settings.Container(contentWidth: 450) {
      Settings.Section(label: { Text("Toggle Panel") }) {
        KeyboardShortcuts.Recorder(for: .togglePanel)
          .accessibilityLabel(Text("Toggle Panel"))
      }

      Settings.Section(label: { Text("Collapsed icon") }) {
        HStack {
          Slider(value: $iconScale, in: ClippyRules.panelScaleRange, step: ClippyRules.panelScaleStep)
            .frame(width: 200)
            .accessibilityLabel(Text("Collapsed icon"))
          Text("\(Int((iconScale * 100).rounded()))%")
            .monospacedDigit()
            .fixedSize()
            .frame(minWidth: 40, alignment: .trailing)
        }
      }

      Settings.Section(label: { Text("Font size") }) {
        HStack {
          Slider(value: $fontScale, in: ClippyRules.panelScaleRange, step: ClippyRules.panelScaleStep)
            .frame(width: 200)
            .accessibilityLabel(Text("Font size"))
          Text("\(Int((fontScale * 100).rounded()))%")
            .monospacedDigit()
            .fixedSize()
            .frame(minWidth: 40, alignment: .trailing)
        }
      }

      Settings.Section(label: { Text("Panel size") }) {
        HStack {
          Slider(value: $sizeScale, in: ClippyRules.panelScaleRange, step: ClippyRules.panelScaleStep)
            .frame(width: 200)
            .accessibilityLabel(Text("Panel size"))
          Text("\(Int((sizeScale * 100).rounded()))%")
            .monospacedDigit()
            .fixedSize()
            .frame(minWidth: 40, alignment: .trailing)
        }
      }

      Settings.Section(label: { Text("Background opacity") }) {
        HStack {
          Slider(value: $backgroundOpacity, in: 0.2...1.0, step: 0.1)
            .frame(width: 200)
            .accessibilityLabel(Text("Background opacity"))
          Text("\(Int((backgroundOpacity * 100).rounded()))%")
            .monospacedDigit()
            .fixedSize()
            .frame(minWidth: 40, alignment: .trailing)
        }
      }
    }
  }
}

#Preview {
  PanelSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}
