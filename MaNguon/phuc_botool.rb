# encoding: UTF-8
# Bộ Tool SketchUp (Phúc) – file nạp. Phiên bản bộ ghi ở dòng @version đầu phuc_botool/launcher.rb.
# Kho: https://github.com/nhohoanglux-prog/BoToolSketchUp
require 'sketchup.rb'
require 'extensions.rb'

module PhucBoTool
  unless defined?(@ext)
    hdr = begin
      File.read(File.join(__dir__, 'phuc_botool', 'launcher.rb'), encoding: 'UTF-8')
    rescue StandardError
      ''
    end
    @ext = SketchupExtension.new('Bộ Tool SketchUp (Phúc)', 'phuc_botool/launcher')
    @ext.version = hdr[/@version:\s*(\S+)/, 1] || '1.0.0'
    @ext.creator = 'BoToolSketchUp'
    @ext.copyright = '2026'
    @ext.description = 'Bảng tool kiểu Tool Launcher: tìm kiếm, chia nhóm, bấm là chạy, tự cập nhật từ GitHub. ' \
                       'Mở: Extensions > Bộ Tool SketchUp (Phúc), hoặc nút trên thanh công cụ.'
    Sketchup.register_extension(@ext, true)
  end
end
