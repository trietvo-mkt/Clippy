// PROTOTYPE (throwaway): views for the three Panel variants.
import AppKit
import SwiftUI

struct PanelPrototypeRootView: View {
  @ObservedObject var model: PanelPrototypeModel
  let proto: PanelPrototype

  // Reads History.shared inside body, so the @Observable tracking refreshes the view.
  private var clips: [(Int, String)] {
    let texts = History.shared.unpinnedItems
      .map { $0.text }
      .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    // Whole History. The index is only a ForEach id and a debug-log value.
    return Array(texts.enumerated().map { ($0.offset + 1, $0.element) })
  }

  var body: some View {
    switch model.variant {
    case .rightStrip: rightStrip.modifier(RegularCard())
    case .bottomShelf: bottomShelf.modifier(RegularCard())
    case .floatingCompact: floatingCompact
    }
  }

  private struct RegularCard: ViewModifier {
    func body(content: Content) -> some View {
      content
        .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }

  private func isCurrent(_ text: String) -> Bool { model.currentText == text }

  private func preview(_ text: String) -> String {
    String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300))
  }

  // Variant A
  private var rightStrip: some View {
    VStack(spacing: 6) {
      PanelPrototypeDebugBar(model: model, proto: proto)
      ScrollView {
        VStack(spacing: 4) {
          ForEach(clips, id: \.0) { idx, text in
            HStack(alignment: .top) {
              Text(preview(text)).lineLimit(2).truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .background(rowBackground(text))
            .contentShape(Rectangle())
            .onTapGesture { proto.select(index: idx, text: text) }
          }
        }
        .padding(.horizontal, 8)
      }
    }
    .padding(.vertical, 8)
  }

  // Variant B
  private var bottomShelf: some View {
    VStack(spacing: 6) {
      PanelPrototypeDebugBar(model: model, proto: proto)
      ScrollView(.horizontal) {
        HStack(spacing: 8) {
          ForEach(clips, id: \.0) { idx, text in
            VStack(alignment: .leading, spacing: 2) {
              Text(preview(text)).lineLimit(1).truncationMode(.tail)
            }
            .padding(8)
            .frame(width: 170)
            .background(rowBackground(text))
            .contentShape(Rectangle())
            .onTapGesture { proto.select(index: idx, text: text) }
          }
        }
        .padding(.horizontal, 8)
      }
    }
    .padding(.vertical, 6)
  }

  // Variant C
  @ViewBuilder
  private var floatingCompact: some View {
    if model.collapsed {
      Button { proto.setCollapsed(false) } label: {
        Image(systemName: "list.bullet.clipboard").font(.title2)
      }
      .buttonStyle(.plain)
      .frame(width: 44, height: 44)
      .background(PanelGlassBackground(style: model.glass, collapsed: true))
    } else {
      VStack(spacing: 6) {
        HStack {
          Text("Clippy").font(.caption).foregroundStyle(.secondary)
          Spacer()
          Button { proto.setCollapsed(true) } label: { Image(systemName: "minus.circle") }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        ScrollView {
          VStack(spacing: 2) {
            ForEach(clips, id: \.0) { idx, text in
              HStack {
                Text(preview(text)).lineLimit(1).truncationMode(.tail)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
              .padding(.vertical, 5).padding(.horizontal, 8)
              .background(rowBackground(text))
              .contentShape(Rectangle())
              .onTapGesture { proto.select(index: idx, text: text) }
            }
          }
          .padding(.horizontal, 6)
        }
        PanelPrototypeDebugBar(model: model, proto: proto)
      }
      .padding(.vertical, 8)
      .background(PanelGlassBackground(style: model.glass, collapsed: false))
    }
  }

  private func rowBackground(_ text: String) -> some View {
    let idle = model.variant == .floatingCompact ? 0.05 : 0.07
    return RoundedRectangle(cornerRadius: 6)
      .fill(isCurrent(text) ? Color.accentColor.opacity(0.35) : Color.primary.opacity(idle))
  }
}

struct PanelPrototypeDebugBar: View {
  @ObservedObject var model: PanelPrototypeModel
  let proto: PanelPrototype

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 6) {
        Button("◀") { proto.setVariant(model.variant.prev) }
        Text("\(model.variant.letter) (\(model.variant.title))")
        Button("▶") { proto.setVariant(model.variant.next) }
        Text("key: \(model.isKey ? "yes" : "no")")
        Text("front: \(model.frontmost)").lineLimit(1)
      }
      HStack(spacing: 6) {
        Button("level: \(model.levelName)") { proto.cycleLevel() }
        Button("canBecomeKey: \(model.canBecomeKey ? "on" : "off")") { proto.toggleCanBecomeKey() }
        Button("glass: \(model.glass.label)") { proto.cycleGlass() }
      }
      Text(model.log).lineLimit(1).truncationMode(.middle)
    }
    .buttonStyle(.plain)
    .font(.system(size: 9, design: .monospaced))
    .foregroundStyle(.white)
    .padding(.horizontal, 8).padding(.vertical, 4)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Capsule().fill(Color.black.opacity(0.85)))
    .padding(.horizontal, 6)
  }
}

// Behind-window blur. state = .active because the app is never active.
struct PanelVisualEffect: NSViewRepresentable {
  let material: NSVisualEffectView.Material
  let radius: CGFloat

  func makeNSView(context: Context) -> NSVisualEffectView {
    let v = NSVisualEffectView()
    v.blendingMode = .behindWindow
    v.state = .active
    v.wantsLayer = true
    v.layer?.masksToBounds = true
    return v
  }

  func updateNSView(_ v: NSVisualEffectView, context: Context) {
    v.material = material
    v.state = .active
    v.layer?.cornerRadius = radius
  }
}

struct PanelGlassBackground: View {
  let style: PanelPrototypeGlass
  // Collapsed is the 44pt rounded-square button.
  let collapsed: Bool

  var body: some View {
    let radius: CGFloat = collapsed ? 10 : 12
    switch effective {
    case .hud:
      PanelVisualEffect(material: .hudWindow, radius: radius)
    case .light:
      PanelVisualEffect(material: .popover, radius: radius)
        .overlay(Color.white.opacity(0.05).clipShape(RoundedRectangle(cornerRadius: radius)))
    case .liquid:
      liquid
    }
  }

  // Liquid Glass needs macOS 26, so older systems use hud.
  private var effective: PanelPrototypeGlass {
    if style == .liquid, #unavailable(macOS 26.0) { return .hud }
    return style
  }

  @ViewBuilder
  private var liquid: some View {
    if #available(macOS 26.0, *) {
      Color.clear.glassEffect(.regular, in: RoundedRectangle(cornerRadius: collapsed ? 10 : 12))
    } else {
      PanelVisualEffect(material: .hudWindow, radius: collapsed ? 10 : 12)
    }
  }
}
