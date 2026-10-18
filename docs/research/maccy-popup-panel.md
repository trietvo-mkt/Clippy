# Popup của Maccy và khả năng gắn Panel luôn nổi

Issue: #2. Nguồn chính là code Maccy trong `Maccy/` (commit `32d42c7`). Phần hành vi của cờ window (`collectionBehavior`, `level`) dựa vào tài liệu AppKit và chưa chạy thử trên máy; mục "Rủi ro" liệt kê những điểm cần prototype.

## Kết luận

Tiếp tục với fork. Maccy đã có sẵn một `NSPanel` non-activating, nổi, hiện trên fullscreen app. Panel của Clippy là một `NSPanel` thứ hai, đặt trong file riêng, dùng chung `History` với popup. Phải sửa một ít code Maccy (khoảng 3 chỗ, nêu ở mục "Chỗ phải sửa file Maccy"), còn lại là file mới.

## 1. Popup là gì và có những cờ nào

- Popup là `FloatingPanel<Content>`, subclass của `NSPanel` (`FloatingPanel.swift:6`). Nội dung là SwiftUI, nhúng qua `NSHostingView` (`FloatingPanel.swift:55`).
- `styleMask` có `.nonactivatingPanel` (`FloatingPanel.swift:27`), cộng `.resizable`, `.closable`, `.fullSizeContentView`.
- `isFloatingPanel = true` (`:39`) và `level = .statusBar` (`:41`). Có TODO về Chrome autofill dùng layer 999, nên level này đã từng va chạm với window khác.
- `collectionBehavior = [.auxiliary, .stationary, .moveToActiveSpace, .fullScreenAuxiliary]` (`:42`). `.fullScreenAuxiliary` cho phép hiện trên fullscreen app. `.moveToActiveSpace` làm window chuyển sang Space đang active mỗi lần hiện, nên không phải "có mặt trên mọi Space" (`.canJoinAllSpaces`). Hai cờ này loại trừ nhau theo tài liệu AppKit, nên Panel phải đổi cờ này.
- `hidesOnDeactivate = false` (`:46`), `animationBehavior = .none` (`:38`), `isMovableByWindowBackground = true` (`:45`).
- `canBecomeKey` trả `true` (`:231`) vì popup có ô search cần nhận gõ phím. Khi mở, popup gọi `orderFrontRegardless()` rồi `makeKey()` (`:92-93`), tức là popup chủ động lấy key focus.
- App là agent app: `LSUIElement = true` (`Info.plist:25`), nên không có Dock icon và không có main menu.

Như vậy popup đã không activate app (không đổi frontmost app), nhưng giành key window. Panel của Clippy cần `canBecomeKey = false` và không gọi `makeKey()`.

## 2. Vòng đời popup

Mở:
- Phím tắt global: `KeyboardShortcuts.onKeyDown(for: .popup, ...)` (`Popup.swift:57`) gọi `handleFirstKeyDown` (`:122-134`), mở nếu đang đóng, đóng nếu đang mở.
- Click status item: `panel.toggle(...)` (`AppDelegate.swift:201`).
- Mở lại app: `applicationShouldHandleReopen` (`AppDelegate.swift:123-126`).
- Panel được tạo một lần trong `applicationDidFinishLaunching` (`AppDelegate.swift:113-120`) và giữ ở `AppDelegate.panel` (`:8`).

Đóng:
- Mất key: `resignKey()` gọi `close()` (`FloatingPanel.swift:210-216`), trừ khi có alert, đang drag-and-drop hoặc đang sửa item (`AppState.swift:21-23`). Đây là lý do popup biến mất khi click ra ngoài.
- Esc: `KeyHandlingView` map ra `.close` và gọi `appState.popup.close()` (`Views/KeyHandlingView.swift:155-157`).
- Sau Select: `History.select` gọi `AppState.shared.popup.close()` trước khi copy, ở mọi nhánh (`Observables/History.swift:355, 363, 366, 370`).
- Toggle bằng phím tắt khi đã mở (`Popup.swift:133`, `:170-173`).
- `close()` reset state popup rồi gọi `onClose` (`FloatingPanel.swift:218-228`), và `onClose` gọi `AppState.shared.popup.reset()` (`AppDelegate.swift:117`).

Select trong Maccy: `HistoryItemView.performSelect` (`Views/HistoryItemView.swift:33-42`) gọi `appState.history.select(...)`. Hàm này đóng popup, gọi `Clipboard.shared.copy(...)` (`Clipboard.swift:85`), và chỉ gọi `Clipboard.shared.paste()` khi `pasteByDefault` bật hoặc có phím modifier (`History.swift:357, 365, 368`). `pasteByDefault` mặc định `false` (`Extensions/Defaults.Keys+Names.swift:55`). `paste()` gửi Cmd+V bằng `CGEvent` (`Clipboard.swift:123-149`) và gọi `Accessibility.check()` (`:124`). Panel của Clippy không dùng `paste()`, nên không cần quyền Accessibility cho Panel.

## 3. Dùng lại view History trong window thứ hai

Dữ liệu dùng chung được. Giao diện chỉ dùng lại được một phần.

Dữ liệu:
- `AppState.shared` và `History.shared` là singleton (`AppState.swift:9`). Hai window cùng quan sát một `History` (`@Observable`), nên Clip mới hiện ở cả hai.
- `History.size` mặc định 200 (`Defaults.Keys+Names.swift:71`), khớp History Limit của Clippy; `limitHistorySize` cắt Clip cũ nhất (`History.swift:145-150`).

View:
- `ContentView` là toàn bộ popup: nền glass, `KeyHandlingView`, `SlideoutView` (preview), `HeaderView` (search), `HistoryListView`, `FooterView` (`Views/ContentView.swift:12-53`). Nó tự gọi `history.load()` trong `.task` (`:55-57`) và lắng nghe `didBecomeKey` theo identifier của popup (`:69-86`). Không dùng lại nguyên `ContentView` cho Panel.
- `HistoryListView` dính với popup: nhận `searchQuery` binding và `FocusState` binding (`Views/HistoryListView.swift:5-6`), ghi chiều cao vào `appState.popup.extraTopHeight` và `extraBottomHeight` (`:99`, `:164`), gọi `appState.popup.resize` (`:142`), và dùng `scenePhase` để focus search và highlight Clip đầu (`:119-126`). Không dùng lại nguyên view này.
- `HistoryItemView` và `ListItemView` dùng lại được. Chúng chỉ cần `@Environment(AppState.self)` và `@Environment(ModifierFlags.self)` (`Views/HistoryItemView.swift:26`, `Views/ListItemView.swift:48-49`), cộng hằng số `Popup.itemHeight` và `Popup.cornerRadius` (`ListItemView.swift:121, 129`). Panel chỉ cần `.environment(...)` hai object đó. `HistoryItemView.performSelect` gọi `history.select`, nên cần đổi hành vi, xem mục 5.

## 4. Chỗ gắn code (file riêng)

File mới, không sửa file Maccy:
1. `Clippy/ClippyPanel.swift`: subclass `NSPanel` riêng, không subclass `FloatingPanel` vì `FloatingPanel` có `canBecomeKey = true`, `resignKey` tự đóng, và gọi `AppState.shared.preview/popup/navigator` ở nhiều delegate method (`FloatingPanel.swift:115-216`). Cờ: `.nonactivatingPanel`, `canBecomeKey = false`, `canBecomeMain = false`, `collectionBehavior` có `.canJoinAllSpaces` và `.fullScreenAuxiliary`, bỏ `.moveToActiveSpace`, `hidesOnDeactivate = false`.
2. `Clippy/ClippyPanelView.swift`: root SwiftUI riêng, một `ScrollView` + `ForEach` trên `appState.history.unpinnedItems`, mỗi dòng là `HistoryItemView` hoặc `ListItemView`. Không có search, preview, footer.
3. `Clippy/ClippyController.swift`: tạo và giữ Panel, hiện khi app khởi động.

Điểm móc vào Maccy:
- `AppDelegate.applicationDidFinishLaunching` (`AppDelegate.swift:109-121`): thêm một dòng tạo `ClippyController`.
- `History.shared` / `AppState.shared`: dùng trực tiếp, không cần sửa.

## 5. Chỗ phải sửa file Maccy (rủi ro khi merge upstream)

1. Select không được đổi thứ tự History. Trong Maccy, `Clipboard.copy` ghi `.fromMaccy` lên pasteboard (`Clipboard.swift:112`), rồi gọi `checkForChangesInPasteboard()` (`:118`). Hàm đó tạo `HistoryItem` mới (`:229`) và gửi vào `History.add` qua hook (`:239`). `add` tìm Clip trùng, xóa Clip cũ và chèn bản mới lên đầu (`History.swift:170-184`). Kết quả: Select đưa Clip lên đầu, trái với định nghĩa Select trong `GLOSSARY.md`.
2. Copy trùng nội dung không được gộp. `History.add` gộp trùng qua `findSimilarItem` (`History.swift:170, 509-515`), trong khi `GLOSSARY.md` yêu cầu mỗi Copy tạo một Clip mới. Cần bỏ nhánh gộp, hoặc đổi theo cờ.
3. Select cho Panel cần hàm riêng, không qua `History.select`, vì hàm đó gọi `popup.close()` ở mọi nhánh (`History.swift:355-370`). Hàm riêng đặt trong file Clippy: gọi `Clipboard.shared.copy(item.item)`, không gọi `paste()`.

Ba chỗ này nằm trong `Clipboard.swift` và `History.swift`, là hai file upstream sửa thường xuyên. Cách giữ diff nhỏ: thêm một hook (ví dụ `Clipboard.suppressHistoryAdd`) thay vì viết lại hàm. Chưa kiểm tra tần suất upstream sửa hai file này; nên xem `git log` của chúng trước khi chốt.

Maccy cũng lưu ảnh, file, rich text (`Clipboard.swift:198-227`). Clippy chỉ cần plain text; có thể giới hạn bằng `enabledPasteboardTypes` (đã dùng ở `AppDelegate.swift:33`, `:102`) thay vì xóa code.

## 6. Rủi ro cần prototype

- Click vào SwiftUI view trong panel `canBecomeKey = false`: `.nonactivatingPanel` thường nhận click đầu mà không activate app, nhưng chưa chạy thử với `Button`/`onTapGesture` trong `NSHostingView`. Đây là rủi ro lớn nhất, vì nếu click không đến view thì Panel phải xử lý chuột bằng AppKit.
- Level: `.statusBar` có thể nằm dưới window level cao hơn (TODO ở `FloatingPanel.swift:40`). Panel có thể cần `.screenSaver` hoặc `.popUpMenu`, thử trên fullscreen app thật.
- Panel nằm trên mọi Space cần `.canJoinAllSpaces` (xem mục 1); thử với Space thứ hai và fullscreen Safari/Terminal.
- Popup Maccy và Panel cùng mở một lúc: `Popup.close()` và `SlideoutController.nswindow` đều trỏ cứng tới `AppDelegate.panel` (`Popup.swift:81, 90, 94, 118`; `Observables/SlideoutController.swift:102`; `Views/MovableByWindowBackgroundModifier.swift:9`), nên Panel không bị ảnh hưởng, nhưng `ContentView` dùng `didBecomeKey` theo identifier (`ContentView.swift:69-86`). Đặt identifier khác cho Panel để tránh nhầm.

## 7. Phương án

1. Tiếp tục fork, thêm Panel như mục 4 (khuyến nghị). Đánh đổi: phải sửa `Clipboard.swift`/`History.swift` nhỏ; nếu upstream đổi hai file này thì merge có conflict.
2. Viết app mới, copy lại phần polling pasteboard và lưu SwiftData. Đánh đổi: mất toàn bộ phần đã chạy ổn (theo dõi pasteboard `Clipboard.swift`, lưu `Storage.swift`, ignore app, update Sparkle) và phải viết lại, đổi lại không có conflict merge. Với một app cá nhân chỉ cần plain text, phần lớn Maccy là dư, nhưng dư không gây hại vì có thể tắt.

Chọn phương án 1. Nếu prototype ở mục 6 cho thấy click không đến SwiftUI view trong panel không key, vẫn không cần bỏ fork, vì chỉ phải đổi cách bắt chuột của Panel (file Clippy), không đụng Maccy.
