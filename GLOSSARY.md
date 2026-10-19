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
Số Clip tối đa History giữ, mặc định 20, tối đa 50. Khi vượt, Clip cũ nhất chưa pin bị xóa. Pinned Clip không tính vào History Limit.
_Avoid_: size, capacity

**Pinned Clip**:
Clip ông đã pin trong Popup. Pinned Clip không bao giờ bị xóa vì History Limit. Trên Panel, Pinned Clip nằm theo thời điểm Copy như Clip thường.
_Avoid_: favorite, starred clip

**Current Clip**:
Clip cụ thể ông vừa Copy hoặc Select, nếu clipboard hệ thống chưa đổi từ lúc đó. Cmd+V sẽ dán ra Clip này. Khi nhiều Clip trùng nội dung, chỉ đúng Clip đó là Current Clip. Clipboard đổi vì một lần ghi mà Clippy bỏ qua (ví dụ password) thì không Clip nào là Current Clip.
_Avoid_: active clip, selected clip

### Hành động

**Copy**:
Ông copy text từ một app khác. Mỗi lần Copy tạo một Clip mới ở đầu History, kể cả khi nội dung trùng với Clip đã có. Copy file hoặc ảnh không có text không tạo Clip.
_Avoid_: capture, record

**Select**:
Ông chọn một Clip trên Panel hoặc Popup để nó thành Current Clip. Select không tạo Clip mới và không đổi thứ tự History. Popup có thể tự dán sau khi Select; việc dán đó không thuộc Select.
_Avoid_: pick, choose, paste

### Giao diện

**Panel**:
Cửa sổ của Clippy hiển thị History, luôn nổi trên các app khác và không giành focus.
_Avoid_: popup, overlay, window

**Popup**:
Cửa sổ Shift+Cmd+C kế thừa từ Maccy. Mở bằng hotkey, đóng sau khi Select. Popup và Panel hiển thị cùng một History.
_Avoid_: menu, Panel
