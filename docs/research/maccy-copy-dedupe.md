# Maccy ghi nhận Copy và gộp Clip trùng ở đâu

Nguồn: code trong thư mục `Maccy/` của fork, branch `research/maccy-copy-dedupe`. Số dòng lấy từ checkout này. Thuật ngữ (Clip, History, Copy, Select...) theo `GLOSSARY.md`. Trong code, Maccy gọi Clip là `HistoryItem`.

## Tóm tắt

Maccy poll `NSPasteboard.changeCount` mỗi 0.5 giây, tạo `HistoryItem` ở `Clipboard.swift:229`, rồi `History.add` (`History.swift:161`) xóa Clip cũ có nội dung trùng và chèn Clip mới lên đầu. Maccy không bỏ qua lần ghi clipboard của chính nó khi Select: marker `fromMaccy` chỉ dùng để bỏ qua nội dung khi so trùng, nên Select đi qua cùng đường với Copy và đẩy Clip lên đầu. Clippy phải sửa 9 chỗ, liệt kê ở mục "Change points".

## 1. Theo dõi clipboard và tạo Clip

- `Clipboard.start()` tạo `Timer` lặp theo `Defaults[.clipboardCheckInterval]` và gọi `checkForChangesInPasteboard` (`Clipboard.swift:54-62`). Mặc định 0.5 giây (`Extensions/Defaults.Keys+Names.swift:29`). Maccy không dùng notification, chỉ poll.
- `checkForChangesInPasteboard` thoát ngay nếu `pasteboard.changeCount == changeCount` đã lưu (`Clipboard.swift:162-164`), rồi cập nhật `changeCount` (`:166`).
- Hàm gom mọi `NSPasteboardItem` thành một danh sách `HistoryItemContent` (`:198-223`), tạo `HistoryItem(contents:)` (`:229`), gán `application` và `title` (`:236-237`), rồi gọi các hook đã đăng ký (`:239`).
- `AppDelegate.swift:54` đăng ký hook duy nhất: `Clipboard.shared.onNewCopy { History.shared.add($0) }`. Đây là điểm vào duy nhất từ clipboard vào History.
- `History.add` chạy theo thứ tự: chèn item vào storage (`History.swift:162-167`), tìm trùng (`:170`), xóa bản cũ nếu trùng (`:171-189`), cắt bớt theo History Limit (`:198`), chèn vào danh sách đã sắp xếp (`:203-213`).

## 2. Logic gộp trùng hiện tại

- `findSimilarItem` (`History.swift:509-515`) trả về item đầu tiên mà `supersedes` item mới. Nếu không có, nó dùng `isModified` (`:517-523`).
- `HistoryItem.supersedes` (`Models/HistoryItem.swift:95-103`) trả `true` khi mọi content của item mới, trừ các type trong `transientTypes`, đều có content cùng `type` và cùng `value` ở item cũ. `transientTypes` gồm cả `fromMaccy` và `source` (`:64-74`). Vì vậy một Clip cũ có nhiều type hơn vẫn "chứa" Clip mới.
- Khi tìm thấy trùng, `add` làm các việc sau (`History.swift:170-189`):
  - copy `firstCopiedAt`, cộng dồn `numberOfCopies`, giữ `pin` và `title` từ item cũ (`:174-177`);
  - xóa item cũ khỏi `allUnpinnedItems` và khỏi storage (`:182-189`).
  Kết quả: một Clip duy nhất, nằm đầu History.
- `isModified` dùng `sessionLog[changeCount]` để nối một Copy với Clip mà một app "sửa" lại (type `x.nspasteboard.ModifiedType`, `Extensions/NSPasteboard.PasteboardType+Types.swift:16`). Nó chỉ phục vụ gộp, Clippy không cần.
- Thứ tự History do `Sorter` quyết định, mặc định `lastCopiedAt` giảm dần (`Sorter.swift:26`, `:56-64`, default ở `Defaults.Keys+Names.swift:72`). Có hai chế độ khác: `firstCopiedAt` và `numberOfCopies`. Clippy yêu cầu "mới nhất ở đầu" nên các chế độ này thừa.

## 3. Nhận ra lần ghi clipboard của chính Maccy

Maccy đánh dấu bằng pasteboard type riêng `org.p0deje.Maccy` (`fromMaccy`, `NSPasteboard.PasteboardType+Types.swift:19`).

- Select từ popup: `History.select` (`History.swift:349-381`) gọi `Clipboard.copy(item)` (`Clipboard.swift:85-120`). Hàm này `clearContents`, ghi lại các type, ghi marker `fromMaccy` (`:112`) và `source` (`:113`), rồi gọi `checkForChangesInPasteboard()` ngay (`:116-119`).
- `copyInMaccy` (dùng cho text của ô tìm kiếm và OCR, `AppState.swift:76`, `Views/ToolbarView.swift:124`) ghi marker bằng cách khác: đặt giá trị của type `source` thành chuỗi `fromMaccy` (`Clipboard.swift:79`).
- Chỗ duy nhất kiểm tra marker khi nhận Copy là `Clipboard.swift:168`. Nó chỉ dùng để quyết định có ngắt Paste Stack hay không (`interruptPasteStack`), rồi code chạy tiếp. Không có `return`.
- Kết luận: lần ghi của Select không bị bỏ qua. `checkForChangesInPasteboard` tạo `HistoryItem` mới. `HistoryItem.fromMaccy` (`Models/HistoryItem.swift:230`) chỉ được đọc ở `History.swift:178`, để giữ `application` cũ. Do `supersedes` bỏ qua `fromMaccy`, item mới trùng với Clip vừa Select, bản cũ bị xóa và bản mới lên đầu. Đây là hành vi Select đang đổi thứ tự History, trái quy tắc của Clippy.

## 4. History Limit

- Key: `Defaults.Keys.size` = `Key<Int>("historySize", default: 200, ...)` (`Defaults.Keys+Names.swift:71`). Lưu trong `UserDefaults` suite `preferencesSuite`. Mặc định 200, Clippy cần 10.
- Giới hạn trên nằm ở UI: `Stepper` `1...999` (`Settings/StorageSettingsPane.swift:101`) và `formatter.maximum = 999` (`:68`). Không có chỗ nào khác chặn giá trị. Ai ghi thẳng `UserDefaults` vẫn vượt được, nên Clippy cần clamp khi đọc.
- Áp dụng giới hạn:
  - lúc load: `limitHistorySize(to: Defaults[.size])` (`History.swift:135`);
  - lúc thêm: `limitHistorySize(to: item.pin == nil ? Defaults[.size] - 1 : Defaults[.size])` (`:198`).
- `limitHistorySize` (`:144-149`) xóa phần tử từ vị trí `maxSize` trở đi của `allUnpinnedItems`, tức xóa Clip cũ nhất. Giới hạn chỉ tính Clip không pin. Pin không bị đếm vào limit và không bị xóa.
- Vì không còn gộp trùng, nhánh "size đã giữ nguyên nên không xóa" (comment `:196-197`) sai. Mỗi Copy luôn thêm một Clip, nên luôn có thể phải xóa một Clip cũ nhất.

## 5. Lọc loại nội dung và nội dung nhạy cảm

- Các type Maccy đọc: `fileURL, html, png, rtf, string, tiff` (`Clipboard.swift:19-26`). `jpeg` và `heic` được bật qua `StorageType.images` (`Defaults.Keys+Names.swift:5-8`).
- Người dùng bật/tắt theo nhóm trong Settings: `enabledPasteboardTypes`, mặc định là tất cả (`Defaults.Keys+Names.swift:30-31`; UI ở `StorageSettingsPane.swift:12-38`). Mỗi lần Copy, `disabledTypes` bị trừ khỏi content (`Clipboard.swift:38`, `:209-211`).
- Một Copy bị bỏ nếu `pasteboard.types` không giao với `enabledTypes` (`Clipboard.swift:246`). Hai chỗ bỏ qua string rỗng: `:201-203` (item chỉ có `.string` rỗng và không phải rich text) và `:225-227` (không còn content nào).
- Nội dung nhạy cảm: `ignoredTypes = [autoGenerated, concealed, transient]` (`Clipboard.swift:27-31`). `concealed` là `org.nspasteboard.ConcealedType` (`NSPasteboard.PasteboardType+Types.swift:11`). Nếu `pasteboard.types` có bất kỳ type nào trong tập này, hàm thoát (`Clipboard.swift:186-188`, `:242-248`). Người dùng thêm type riêng qua `ignoredPasteboardTypes` (`Defaults.Keys+Names.swift:39`). Quy tắc "bỏ nội dung password manager đánh dấu nhạy cảm" của Clippy đã có sẵn, không cần sửa.
- Các bộ lọc khác Clippy không cần: `ignoredApps` (`:190-192`, `:250-256`), `ignoreRegexp` (`:205-207`, `:258-272`), `ignoreEvents` (`:174-181`).
- Vì mỗi content giữ mọi type cho phép (html, rtf, string, hình, file), một Clip hiện có thể mang rich text. Clippy chỉ lưu plain text, nên chỉ giữ `.string`.

## 6. Nơi lưu History xuống đĩa

- `Storage` (`Storage.swift:6-35`) tạo `ModelContainer` SwiftData tại `~/Library/Application Support/Maccy/Storage.sqlite` (`:19`, `:22`, `:31`). Khi test, dùng bộ nhớ (`:24-28`).
- Model: `HistoryItem` (`Models/HistoryItem.swift:7-8`) với các trường `application, firstCopiedAt, lastCopiedAt, numberOfCopies, pin, title` (`:77-82`) và quan hệ cascade tới `HistoryItemContent` (`:84-85`). Mỗi type của pasteboard là một `HistoryItemContent` riêng (`type`, `value`).
- Nạp lúc khởi động: `History.load()` fetch toàn bộ `HistoryItem` (`History.swift:125-142`), gọi từ `Views/ContentView.swift:56`.
- Ghi: `insertIntoStorage` insert và `save()` ngay (`History.swift:151-157`).
- Còn có thư mục `Maccy/Storage.xcdatamodeld` và `Maccy/History.xcdatamodeld` (model Core Data cũ). Tôi chưa mở chúng. Có thể chúng chỉ phục vụ migration.

## Change points

| # | File:dòng | Hiện tại | Clippy cần |
|---|---|---|---|
| 1 | `History.swift:170-189` (`findSimilarItem` ở `:509-515`) | Xóa Clip cũ trùng nội dung, giữ một bản ở đầu | Bỏ nhánh gộp trùng. Mỗi Copy luôn tạo Clip mới, cả khi trùng |
| 2 | `Models/HistoryItem.swift:95-103` (`supersedes`), `History.swift:326-330` (`transferContents`), `:517-523` (`isModified`), `:200` (`sessionLog`) | Hỗ trợ gộp: so content, chuyển content, nối với bản "modified" | Xóa, vì chỉ phục vụ gộp |
| 3 | `Clipboard.swift:168-172` | Thấy `fromMaccy` thì chỉ bỏ qua việc ngắt Paste Stack, rồi vẫn tạo Clip | Thấy `fromMaccy` (lần ghi của Select) thì `return` sớm: không tạo Clip, không đổi History |
| 4 | `Clipboard.swift:112-119` (cuối `copy`) | Gọi `checkForChangesInPasteboard()` ngay sau khi ghi | Cập nhật `changeCount` thay vì quét lại, để lần poll kế tiếp không coi đó là Copy. Đặt Current Clip cho Select |
| 5 | `History.swift:349-381` (`select`) | Mỗi nhánh gọi `Clipboard.copy`, rồi (qua poll) đưa Clip lên đầu | Chỉ ghi clipboard, không thêm hay xếp lại. Nhánh `paste`, `pasteWithoutFormatting` và `closePopup` bỏ nếu Panel không dán |
| 6 | `Defaults.Keys+Names.swift:71` | `historySize` mặc định 200 | Mặc định 10 |
| 7 | `Settings/StorageSettingsPane.swift:68`, `:101`; đọc ở `History.swift:135`, `:198` | Tối đa 999, chỉ chặn ở UI | Tối đa 200. Clamp `1...200` khi đọc `Defaults[.size]` để giá trị lạ trong `UserDefaults` không vượt |
| 8 | `History.swift:196-198` | `Defaults[.size] - 1` vì "bản trùng giữ nguyên size" | Xóa lệch này. Mỗi Copy thêm đúng một Clip, nên luôn cắt về `size - 1` trước khi chèn (hoặc cắt về `size` sau khi chèn). `limitHistorySize` (`:144-149`) cũng bỏ qua pin, quyết định có giữ pin hay không thuộc thiết kế Panel |
| 9 | `Clipboard.swift:19-26`, `:198-223`; `Defaults.Keys+Names.swift:5-8`, `:30-31` | Lưu mọi type: file, ảnh, html, rtf, string | Chỉ lưu `.string`. Bỏ `fileURL`, ảnh, html, rtf khỏi `supportedTypes` và `enabledPasteboardTypes`, bỏ tab chọn loại ở Settings. Copy không có `.string` thì bỏ qua |

Không cần sửa: poll `changeCount` (`Clipboard.swift:54-66`) giữ nguyên, và bộ lọc nội dung nhạy cảm (`Clipboard.swift:27-31`, `:186-188`) đã khớp quy tắc. Mục 3 chỉ có hiệu lực nếu poll đọc marker trước khi `changeCount` của lần ghi Select bị coi là Copy mới.

## Rủi ro

- Nếu change point 3 và 4 sai, mỗi lần Select tạo một Clip trùng ở đầu History. Đây là lỗi dễ thấy nhất.
- Ứng dụng khác có thể ghi `ModifiedType` hoặc copy lại đúng chuỗi vừa Select. Lần copy đó là Copy thật, vẫn tạo Clip mới. Marker `fromMaccy` do Clippy đặt nên không bị nhầm với app khác.
- Bỏ gộp trùng làm `numberOfCopies`, `firstCopiedAt` và chế độ sort `numberOfCopies` mất ý nghĩa. Cần xóa hoặc cố định `sortBy = lastCopiedAt`.
- Dữ liệu cũ trong `Storage.sqlite` của Maccy có thể chứa ảnh và file. Fork dùng chung đường dẫn `Maccy/Storage.sqlite` (`Storage.swift:19`). Cần chọn đường dẫn riêng hoặc bỏ qua content không phải text khi load.
