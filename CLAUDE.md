# BoToolSketchUp – ghi chú cho Claude

Đọc file này thay vì đọc lại lịch sử chat dài.

## Người dùng (phúc)
- Luôn trả lời bằng tiếng Việt có dấu đầy đủ. Hỏi vài câu ngắn để hiểu đúng trước khi làm.
- Không rành code: mỗi lần giao chỉ gửi MỘT file zip + hướng dẫn ngắn, từng bước.
- SketchUp 2021 trên Windows 11, làm kiến trúc.

## MỖI PHẦN MỀM MỘT KHO (người dùng yêu cầu 2026-11-26)
Người dùng hay chia sẻ bộ tool cho người khác, nên mỗi phần mềm có kho GitHub riêng:
- Photoshop: nhohoanglux-prog/BoToolPhotoshop (panel Tool Launcher, tool .jsx). KHÔNG đổi tên kho đó (panel cập nhật theo tên).
- SketchUp: kho này, nhohoanglux-prog/BoToolSketchUp (công khai).
- Phần mềm mới (InDesign, AutoCAD…) thì tạo kho mới BoTool<TênPhầnMềm>, có CLAUDE.md + CHANGELOG.md riêng.
Không để code SketchUp vào kho Photoshop và ngược lại.

## Cấu trúc kho: MỘT bộ "Bộ Tool SketchUp" (người dùng yêu cầu 2026-11-26: giống bộ Photoshop, không đặt theo tên 1 tool)
```
MaNguon/                         = đúng cấu trúc thư mục Plugins của SketchUp (cũng là nội dung .rbz)
  phuc_botool.rb                 file nạp (register_extension "Bộ Tool SketchUp (Phúc)", version đọc từ launcher.rb)
  phuc_botool/launcher.rb        bảng tool + cập nhật; dòng @version/@date đầu file = phiên bản BỘ
  phuc_botool/launcher.html      giao diện bảng (tìm không dấu, nhóm thu gọn, nhãn MỚI, khung Có bản mới)
  phuc_botool/icons.js           icon Lucide (chép từ panel Photoshop, ISC, icons-LICENSE.txt), dùng TL_iconSvg
  phuc_botool/icon.svg           icon nút thanh công cụ
  phuc_botool/tools/<Id>/main.rb mỗi tool 1 thư mục; đầu file có @name @group @desc @version @date @icon @module
capnhat.json                     do dong_goi.py tạo: version/date/notes của bộ, tools[{id,name,version,date,notes}], files
BoToolSketchUp.rbz               do dong_goi.py tạo (cài lần đầu)
HuongDan.txt                     hướng dẫn cài (UTF-8 BOM, CRLF)
```
Bảng (module PhucBoTool): quét tools/*/main.rb, đọc header; bấm tool = `load` main.rb (khi mtime đổi) rồi gọi
`<@module>.show`. Menu Extensions > Bộ Tool SketchUp (Phúc) > Mở bảng tool + từng tool; toolbar "Bộ Tool SketchUp".
Cập nhật: sha qua api.github.com/repos/nhohoanglux-prog/BoToolSketchUp/commits/main (lỗi thì main/), đọc raw <sha>/capnhat.json,
so bộ + từng tool (tool mới chưa có cũng tính), tải HẾT file trong "files" từ raw <sha>/MaNguon/<f> rồi mới ghi vào
thư mục Plugins (File.dirname(ROOT)), lưu id tool vừa cập nhật vào Sketchup default PhucBoTool/new (nhãn MỚI, mất khi bấm chạy),
nạp lại launcher.rb + tải lại trang, tool nạp lại ở lần bấm sau → KHÔNG cần tắt SketchUp. Hằng số dùng `unless defined?`.
disable_old(): đổi tên Plugins/phuc_mat_bang_xien.rb (bản cài riêng v1.0–1.2) thành .rb.cu.
Mô phỏng kiểm thử: Ruby thường + mock Sketchup::Http/UI (không nằm trong kho). CHƯA chạy trên SketchUp thật.

## Thêm tool mới
1. Tạo MaNguon/phuc_botool/tools/<Id>/main.rb (+ dialog.html nếu cần), module riêng `PhucBoTool::<Id>` có `self.show`.
   Đầu file:
   ```
   # encoding: UTF-8
   # @name: Tên hiện trong bảng
   # @group: Nhóm (Diễn họa, Mô hình, Xuất file...)
   # @desc: Một dòng mô tả ngắn.
   # @version: 1.0.0
   # @date: 2026-11-26
   # @icon: layers          (tên icon Lucide có trong icons.js)
   # @module: PhucBoTool::<Id>
   ```
   Không đăng ký menu/extension riêng trong tool (bảng lo). Không dùng hằng số VERSION (đọc @version từ file).
2. CHANGELOG.md thêm `- <Id> v1.0.0: ...` (thiếu thì dong_goi.py báo lỗi).

## Khi sửa tool / bảng
1. Sửa code. Tăng @version + @date của tool đó; sửa bảng thì tăng @version + @date đầu launcher.rb.
2. CHANGELOG.md thêm dòng vào đầu mục ngày: `- MatBangXien v1.4.0: ...` hoặc `- Bộ Tool SketchUp v1.1.0: ...`.
3. `python3 dong_goi.py` → capnhat.json, BoToolSketchUp.rbz, /mnt/project-files/BoToolSketchUp.zip. Commit, push main.
4. Báo người dùng: mở bảng Bộ Tool là thấy "🔔 Có bản mới", bấm "⬇ Cập nhật ngay" (không cần tắt SketchUp).
   Chỉ gửi zip khi cài lần đầu hoặc khi đổi phuc_botool.rb (file nạp).
5. Tự cập nhật CLAUDE.md + CHANGELOG.md sau mỗi việc, không cần nhắc.

## BÁO TIẾN ĐỘ (người dùng yêu cầu 2026-11-26, BẮT BUỘC cho mọi tool chạy lâu)
Người dùng không biết tool có đang chạy không. Ruby chạy trên luồng chính nên hộp thoại không vẽ lại khi bận:
chia việc thành các bước, chạy bằng run_steps(title, [[tên bước, lambda]]) { chữ báo xong } (xem MatBangXien/main.rb):
mỗi bước trong UI.start_timer(0.05) riêng, trước bước gọi js progStep + Sketchup.status_text; bước trả false (stop_with)
= dừng có lý do; lỗi thì abort_operation nếu @op_open. Phía HTML chép khối CSS #prog + progStart/progStep/progDone/progFail
(khung dính đáy, thanh %, đồng hồ giây, vòng xoay CSS, khoá nút khi BUSY). Một lệnh nặng (add_group/copy, write_image)
không chia nhỏ được thì ghi rõ trong tên bước "có thể mất vài chục giây".

## Tool "Mặt bằng xiên" (tools/MatBangXien, module PhucBoTool::MatBangXien)
v1.5.0: build/export chạy qua run_steps (Dựng: 5 bước; Xuất: 1 bước mỗi cao độ + trả cao độ + kiểm tra), khung tiến độ.
v1.4.0 (2026-11-26): NGƯỜI DÙNG ĐÃ CHẠY ĐƯỢC trên SketchUp thật (ảnh nền đen nét trắng ra đúng), phàn nàn nét dày, muốn
nét tinh gọn + xuất rõ (PDF). write_png: write_image thêm scale_factor (ô "Nét khi xuất", mặc định 1; SketchUp 2019.2+
mặc định nhân nét 2× khi xuất ảnh lớn; khoá CHƯA kiểm chứng, lỗi thì xuất lại không có khoá). write_pdf: model.export PDF
với khoá Exporter Options Windows (match_screen_* false, line_width/line_width_section = mm/25.4 Float, full_scale false);
cần SketchUp Pro; CHƯA kiểm chứng màu nền/tô cắt trong PDF. Preset "Như ref" giờ profile 1, cutw 2, depth 0.
v1.3.0 (2026-11-26): chuyển vào Bộ Tool, bỏ khối tự cập nhật riêng và menu riêng; link "Mở Bộ Tool SketchUp" trong hộp thoại.
Lịch sử: v1.2.0 (2026-11-26): chuyển từ kho BoToolPhotoshop (thư mục 3_SketchUp) sang kho này; người dùng phải gỡ bản cũ và
cài lại .rbz một lần (bản v1.1.0 cũ trỏ cập nhật về kho Photoshop, nay đã xoá thư mục đó). CHƯA chạy trên SketchUp thật.
Người dùng: SketchUp 2021, kiến trúc, muốn ảnh mặt bằng xiên
(plan oblique) như ref: nền đen, phần cắt trắng, nét mạnh nhạt, có hạt; thêm ref vẽ tay (nền giấy, nét chì mảnh,
mặt bằng xoay 45°, đổ thẳng xuống, cắt nét đậm, bút bi xanh). Phiên bản ở dòng @version đầu main.rb.
Cách làm (main.rb): add_group(vùng chọn) → copy → explode (bản gốc giữ nguyên), bản sao (attribute phuc_mbx/copy)
đặt lệch sang phải ox; transformation = shear quanh zmin (zaxis = (-k·cosθ, -k·sinθ, 1)) × xoay quanh tâm;
section plane riêng trong group (attribute cut) ở zc, pháp tuyến (0,0,-1) (ô "Lật" nếu ngược, CHƯA kiểm chứng chiều);
RenderMode 1 (Hidden Line: mặt tô màu nền) + SectionCutFilled/SectionDefaultFillColor, Profiles, Depth cue, Fog;
camera song song từ trên, view.zoom; xuất view.write_image, nhiều cao độ ";" → mỗi cao độ 1 PNG. "Trả lại như cũ"
khôi phục rendering options + camera + mặt cắt đang bật. Hộp thoại UI::HtmlDialog dialog.html (ES5), lưu thông số
Sketchup.write_default('PhucMatBangXien','params'). Hạt ảnh làm bằng tool Photoshop HatAnh.jsx.
