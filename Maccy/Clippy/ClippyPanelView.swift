import AppKit
import Defaults
import SwiftUI

// Root view of the Panel: the Clip list when expanded, a single icon when collapsed.
struct ClippyPanelView: View {
  var model: ClippyPanelModel

  @Default(.panelIconScale) private var iconScale

  var body: some View {
    if model.collapsed {
      collapsedView
    } else {
      ClippyPanelListView()
    }
  }

  private var collapsedView: some View {
    let side = ClippyPanelLayout.collapsedSize(iconScale: iconScale).width
    return Image(systemName: "list.clipboard")
      .font(.system(size: 20 * iconScale))
      .frame(width: side, height: side)
      .contentShape(Rectangle())
      .onTapGesture { ClippyPanelController.shared.setCollapsed(false) }
  }
}

private struct ClippyPanelListView: View {
  @Default(.panelFontScale) private var fontScale
  @Default(.panelIconScale) private var iconScale

  // Refreshed by the timer. An ignored copy (e.g. a password) bumps changeCount without
  // touching CurrentClip, and the Current Clip highlight must go away then.
  @State private var changeCount = NSPasteboard.general.changeCount

  private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

  // Newest first. Pinned Clips stay in time order, not on top.
  // During an active Popup search these lists are filtered (known v1 limit).
  private var clips: [HistoryItemDecorator] {
    (History.shared.pinnedItems + History.shared.unpinnedItems)
      .sorted { $0.item.lastCopiedAt > $1.item.lastCopiedAt }
  }

  var body: some View {
    VStack(spacing: 0) {
      topBar
      ScrollView {
        LazyVStack(spacing: 3) {
          ForEach(clips) { clip in
            row(clip)
          }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onReceive(timer) { _ in changeCount = NSPasteboard.general.changeCount }
  }

  private var topBar: some View {
    HStack {
      Spacer()
      Button { ClippyPanelController.shared.setCollapsed(true) } label: {
        Image(systemName: "minus").font(.system(size: 12 * iconScale, weight: .semibold))
      }
      .buttonStyle(.plain)
      .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 10)
    .frame(height: 24 * iconScale)
  }

  private func row(_ clip: HistoryItemDecorator) -> some View {
    let isCurrent = CurrentClip.shared.isCurrent(clip.item, pasteboardChangeCount: changeCount)
    return HStack(spacing: 6) {
      Text(clip.title)
        .font(.system(size: 13 * fontScale))
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(maxWidth: .infinity, alignment: .leading)
      if clip.isPinned {
        Image(systemName: "pin.fill")
          .font(.system(size: 9 * fontScale))
          .foregroundStyle(isCurrent ? Color.white.opacity(0.8) : Color.secondary)
      }
    }
    .foregroundStyle(isCurrent ? Color.white : Color.primary)
    .padding(.vertical, 7)
    .padding(.horizontal, 8)
    .background(
      RoundedRectangle(cornerRadius: 6)
        .fill(isCurrent ? Color.accentColor : Color.primary.opacity(0.05))
    )
    .contentShape(Rectangle())
    .onTapGesture {
      Clipboard.shared.copy(clip.item)
      // Read the new changeCount now so the highlight moves without waiting for the timer.
      changeCount = NSPasteboard.general.changeCount
    }
  }
}
