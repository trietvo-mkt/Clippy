# Clippy

App macOS cá nhân giữ lại các đoạn text đã copy và hiển thị chúng trên một Panel luôn nổi, để chọn đoạn sẽ dán tiếp theo.

## Language

### Nội dung

**Clip**:
Một đoạn plain text đã copy, nằm trong History.
_Avoid_: item, entry, mục, snippet

**History**:
Danh sách Clip xếp theo thời điểm Copy, mới nhất ở đầu.
_Avoid_: clipboard list, lịch sử clipboard

**History Limit**:
Số Clip tối đa History giữ, tối đa 200. Khi vượt, Clip cũ nhất bị xóa.
_Avoid_: size, capacity

**Current Clip**:
Clip đang nằm trên clipboard hệ thống, tức thứ Cmd+V sẽ dán ra.
_Avoid_: active clip, selected clip

### Hành động

**Copy**:
Ông copy text từ một app khác. Mỗi lần Copy tạo một Clip mới ở đầu History, kể cả khi nội dung trùng với Clip đã có.
_Avoid_: capture, record

**Select**:
Ông click một Clip trên Panel để nó thành Current Clip. Select không tạo Clip mới và không đổi thứ tự History.
_Avoid_: pick, choose, paste

### Giao diện

**Panel**:
Cửa sổ của Clippy hiển thị History, luôn nổi trên các app khác và không giành focus.
_Avoid_: popup, overlay, window
