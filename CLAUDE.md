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

## Cấu trúc kho (mỗi plugin 1 thư mục cấp 1)
```
dong_goi.py                    đóng gói mọi thư mục có MaNguon/
CHANGELOG.md                   dòng "- <TênThưMục> v<phiên bản>: ..." = ghi chú "Có bản mới"
MatBangXien/MaNguon/           phuc_mat_bang_xien.rb (nạp, VERSION/DATE) + phuc_mat_bang_xien/ (main.rb, dialog.html)
MatBangXien/HuongDan.txt       hướng dẫn cài/dùng (UTF-8 có BOM, CRLF)
MatBangXien/capnhat.json       do dong_goi.py tạo: version, date, notes, files
MatBangXien/MatBangXien.rbz    do dong_goi.py tạo
```
Plugin mới: tạo thư mục mới cùng dạng, module Ruby riêng trong PhucTools, chép khối tự cập nhật của main.rb
(REPO = 'nhohoanglux-prog/BoToolSketchUp', PLUGIN_DIR = '<TênThưMục>/').

## Khi sửa hoặc thêm plugin
1. Sửa code trong <Plugin>/MaNguon/. Tăng VERSION + DATE trong file .rb nạp (và dòng "Phiên bản" đầu main.rb).
2. CHANGELOG.md thêm dòng `- MatBangXien v1.3.0: thay đổi gì` vào đầu mục ngày (thiếu thì dong_goi.py báo lỗi).
3. `python3 dong_goi.py` → tạo lại capnhat.json, .rbz và /mnt/project-files/<Plugin>_SketchUp.zip. Commit, push main.
4. Báo người dùng: mở Extensions > Mặt bằng xiên là thấy "🔔 Có bản mới", bấm "⬇ Cập nhật ngay", tắt mở lại SketchUp.
   Chỉ gửi zip khi cài lần đầu hoặc đổi tên file/thư mục nạp.
5. Tự cập nhật CLAUDE.md + CHANGELOG.md sau mỗi việc, không cần nhắc.

## Plugin "Mặt bằng xiên" (MatBangXien)
v1.2.0 (2026-11-26): chuyển từ kho BoToolPhotoshop (thư mục 3_SketchUp) sang kho này; người dùng phải gỡ bản cũ và
cài lại .rbz một lần (bản v1.1.0 cũ trỏ cập nhật về kho Photoshop, nay đã xoá thư mục đó). CHƯA chạy trên SketchUp thật.
Cơ chế cập nhật (main.rb check_update/do_update): Sketchup::Http::Request lấy sha qua api.github.com/repos/<REPO>/commits/main
(lỗi thì dùng main/), đọc raw <sha>/MatBangXien/capnhat.json, so phiên bản, tải hết các file trong "files"
từ raw <sha>/MatBangXien/MaNguon/<file> rồi mới ghi đè vào thư mục Plugins (File.dirname(__dir__)); tự kiểm tra lúc mở hộp thoại.
Không tự nạp lại code (VERSION là hằng số) nên phải khởi động lại SketchUp. Người dùng: SketchUp 2021, kiến trúc, muốn ảnh mặt bằng xiên
(plan oblique) như ref: nền đen, phần cắt trắng, nét mạnh nhạt, có hạt; thêm ref vẽ tay (nền giấy, nét chì mảnh,
mặt bằng xoay 45°, đổ thẳng xuống, cắt nét đậm, bút bi xanh). Phiên bản ở VERSION/DATE trong phuc_mat_bang_xien.rb.
Cách làm (main.rb): add_group(vùng chọn) → copy → explode (bản gốc giữ nguyên), bản sao (attribute phuc_mbx/copy)
đặt lệch sang phải ox; transformation = shear quanh zmin (zaxis = (-k·cosθ, -k·sinθ, 1)) × xoay quanh tâm;
section plane riêng trong group (attribute cut) ở zc, pháp tuyến (0,0,-1) (ô "Lật" nếu ngược, CHƯA kiểm chứng chiều);
RenderMode 1 (Hidden Line: mặt tô màu nền) + SectionCutFilled/SectionDefaultFillColor, Profiles, Depth cue, Fog;
camera song song từ trên, view.zoom; xuất view.write_image, nhiều cao độ ";" → mỗi cao độ 1 PNG. "Trả lại như cũ"
khôi phục rendering options + camera + mặt cắt đang bật. Hộp thoại UI::HtmlDialog dialog.html (ES5), lưu thông số
Sketchup.write_default('PhucMatBangXien','params'). Hạt ảnh làm bằng tool Photoshop HatAnh.jsx.
