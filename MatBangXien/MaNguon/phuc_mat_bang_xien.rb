# encoding: UTF-8
# Mặt bằng xiên (plan oblique) – BoToolSketchUp
# Phiên bản 1.2.0 – 2026-11-26
require 'sketchup.rb'
require 'extensions.rb'

module PhucTools
  module MatBangXien
    VERSION = '1.2.0' unless defined?(VERSION)
    DATE = '2026-11-26' unless defined?(DATE)
    unless defined?(@loaded_ext)
      ext = SketchupExtension.new('Mặt bằng xiên (Phúc)', 'phuc_mat_bang_xien/main')
      ext.version = VERSION
      ext.creator = 'BoToolSketchUp'
      ext.copyright = '2026'
      ext.description = 'Biến mô hình thành ảnh mặt bằng xiên kiểu axonometric: mặt bằng giữ phẳng, ' \
                        'tường đổ xiên theo góc chọn, cắt ngang ở cao độ chọn, phần cắt tô trắng, nền đen, xuất PNG. ' \
                        'Menu Extensions > Mặt bằng xiên.'
      Sketchup.register_extension(ext, true)
      @loaded_ext = true
    end
  end
end
